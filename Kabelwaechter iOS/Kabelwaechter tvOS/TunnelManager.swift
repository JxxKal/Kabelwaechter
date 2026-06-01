import Foundation
import Observation
import NetworkExtension
import KabelwaechterCore
import KabelwaechterPersistence

/// Wrapper über `NETunnelProviderManager` mit Bezug auf unsere Tunnel-UUIDs.
///
/// Aufgaben:
/// - Lädt alle bestehenden NEVPNManager-Configurations aus den System-
///   Preferences und korreliert sie über die in
///   `providerConfiguration["tunnelID"]` gespeicherte UUID.
/// - Erzeugt / aktualisiert Manager-Konfigurationen bei `connect(tunnelID:)`.
/// - Listet `status(forTunnelID:)` für die UI.
/// - Reagiert auf `NEVPNStatusDidChange`-Notifications.
///
/// Phase-3.2-Scope: nur connect/disconnect/status. Reconnect, On-Demand-Rules,
/// Trigger via Always-On etc. kommen später.
@MainActor
@Observable
final class TunnelManager {

    /// Aktueller Status pro Tunnel — UI bindet hierauf via @Observable.
    private(set) var statuses: [UUID: NEVPNStatus] = [:]

    /// Cached Manager-Instanzen pro Tunnel-UUID. Werden in `refresh()`
    /// aus den System-Preferences geladen.
    private var managers: [UUID: NETunnelProviderManager] = [:]

    /// Bundle Identifier der tvOS Network Extension. Aus den Konstanten
    /// (statt hier hartkodiert), damit Bundle-ID-Schema-Änderungen an einer
    /// Stelle wirken.
    private let providerBundleIdentifier: String = KabelwaechterConstants.BundleIdentifiers.tvOSNetworkExtension

    /// Repository — für Auflösung TunnelID → wg-quick-String beim Connect.
    private let repository: any TunnelRepositoring

    private var statusObserver: NSObjectProtocol?

    init(repository: any TunnelRepositoring) {
        self.repository = repository
        // VPN-Status-Änderungen kommen via NotificationCenter — wir merken sie
        // pro Manager und propagieren in `statuses`.
        statusObserver = NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let conn = note.object as? NEVPNConnection,
                  let manager = conn.manager as? NETunnelProviderManager else { return }
            Task { @MainActor [weak self] in
                self?.recordStatus(for: manager)
            }
        }
    }

    // Kein deinit-cleanup: TunnelManager lebt für die App-Lifetime, der
    // Observer stirbt mit dem Prozess. Swift-6-Isolation würde uns hier
    // ohnehin daran hindern, `statusObserver` aus dem nonisolated deinit
    // zu lesen — und der Aufwand lohnt sich nicht.

    /// Lädt alle Manager aus den System-Preferences und befüllt `statuses`.
    /// Sollte beim App-Start (oder beim Wechsel zu einem Tunnel-Detail)
    /// aufgerufen werden.
    func refresh() async throws {
        let loaded = try await NETunnelProviderManager.loadAllFromPreferences()
        managers.removeAll()
        for manager in loaded {
            guard let id = Self.tunnelID(of: manager) else { continue }
            managers[id] = manager
            statuses[id] = manager.connection.status
        }
        await cleanupOrphanedManagers()
    }

    /// Status für einen bestimmten Tunnel — vor `refresh()` aufgerufen liefert
    /// `nil`, das die UI als "unbekannt" interpretieren kann.
    func status(forTunnelID id: UUID) -> NEVPNStatus? {
        statuses[id]
    }

    /// Baut die NEVPNManager-Konfiguration auf (anlegen oder updaten) und
    /// startet den Tunnel. Wirft, wenn die Tunnel-UUID im Repository
    /// nicht auflösbar ist (z.B. lokaler Tunnel-Instance fehlt).
    /// Baut/aktualisiert die NEVPNManager-Konfiguration für eine Tunnel-UUID
    /// und speichert sie. `onDemand == nil` lässt die bestehende Auto-Connect-
    /// Einstellung unangetastet; `true`/`false` setzt sie explizit.
    /// Startet den Tunnel **nicht**.
    @discardableResult
    private func prepareManager(tunnelID id: UUID, displayName: String, onDemand: Bool?) async throws -> NETunnelProviderManager {
        let config = try repository.tunnelConfiguration(id: id)
        let wgQuick = config.asWgQuickConfig()

        let manager = managers[id] ?? NETunnelProviderManager()
        let proto = (manager.protocolConfiguration as? NETunnelProviderProtocol) ?? NETunnelProviderProtocol()
        proto.providerBundleIdentifier = providerBundleIdentifier
        // serverAddress muss laut Apple-Doku non-empty sein, sonst lehnt
        // NEVPNManager.saveToPreferences ab.
        proto.serverAddress = config.peers.first?.endpoint?.stringRepresentation ?? "kabelwaechter"
        proto.providerConfiguration = [
            "wgQuickConfig": wgQuick,
            "tunnelID": id.uuidString
        ]

        manager.protocolConfiguration = proto
        manager.localizedDescription = displayName
        manager.isEnabled = true
        if let onDemand {
            manager.isOnDemandEnabled = onDemand
            manager.onDemandRules = onDemand ? [NEOnDemandRuleConnect()] : []
        }

        try await manager.saveToPreferences()
        // Nach saveToPreferences müssen wir loadFromPreferences aufrufen,
        // sonst lehnt startVPNTunnel mit "configuration is invalid" ab —
        // Apple-Quirk, dokumentiert in NEVPNManager.h.
        try await manager.loadFromPreferences()
        managers[id] = manager
        return manager
    }

    /// Verbindet manuell (einmalig). Lässt die Auto-Connect-Einstellung wie
    /// sie ist (Default: aus).
    func connect(tunnelID id: UUID, displayName: String) async throws {
        let manager = try await prepareManager(tunnelID: id, displayName: displayName, onDemand: nil)
        try manager.connection.startVPNTunnel()
        statuses[id] = manager.connection.status
    }

    /// Ob Auto-Connect (On-Demand) für diesen Tunnel aktiv ist.
    func isAutoConnect(tunnelID id: UUID) -> Bool {
        managers[id]?.isOnDemandEnabled ?? false
    }

    /// Schaltet Auto-Connect (Always-On via On-Demand) pro Tunnel. Beim
    /// Einschalten wird der Tunnel — falls getrennt — gleich gestartet; das
    /// System hält ihn dann über Netzwechsel und Reboots hinweg verbunden.
    func setAutoConnect(_ enabled: Bool, tunnelID id: UUID, displayName: String) async throws {
        let manager = try await prepareManager(tunnelID: id, displayName: displayName, onDemand: enabled)
        if enabled, manager.connection.status == .disconnected || manager.connection.status == .invalid {
            try manager.connection.startVPNTunnel()
        }
        statuses[id] = manager.connection.status
    }

    /// Stoppt einen aktiven Tunnel und schaltet On-Demand ab — sonst würde der
    /// Tunnel sofort wieder hochkommen. No-op wenn kein Manager existiert.
    func disconnect(tunnelID id: UUID) async {
        guard let manager = managers[id] else { return }
        // On-Demand muss aus, sonst kommt der Tunnel sofort wieder hoch —
        // Trennen bedeutet auch „Auto-Connect aus".
        if manager.isOnDemandEnabled {
            manager.isOnDemandEnabled = false
            manager.onDemandRules = []
            try? await manager.saveToPreferences()
        }
        manager.connection.stopVPNTunnel()
    }

    /// Entfernt die System-NEVPN-Config zu diesem Tunnel (tvOS Settings →
    /// Allgemein → VPN). Aufrufer: free()/delete() in der Detailansicht +
    /// `cleanupOrphanedManagers` nach iCloud-Sync.
    func remove(tunnelID id: UUID) async {
        guard let manager = managers[id] else { return }
        let status = manager.connection.status
        if status != .disconnected && status != .invalid {
            manager.connection.stopVPNTunnel()
        }
        try? await manager.removeFromPreferences()
        managers.removeValue(forKey: id)
        statuses.removeValue(forKey: id)
    }

    /// Räumt System-Configs auf, die laut Repository nicht mehr dieser TV
    /// gehören (anderes Gerät hat den Tunnel beansprucht oder iCloud-Löschung).
    /// Gerufen bei refresh() + nach `.NSPersistentStoreRemoteChange`.
    func cleanupOrphanedManagers() async {
        let me = DeviceIdentity.id
        var byID: [UUID: TunnelView] = [:]
        if let list = try? repository.allTunnels() {
            for t in list { byID[t.id] = t }
        }
        for (id, _) in managers {
            let keep: Bool = {
                guard let t = byID[id] else { return false }
                return t.isOwned(by: me)
            }()
            if !keep {
                await remove(tunnelID: id)
            }
        }
    }

    // MARK: - Live-Statistiken

    /// Momentaufnahme der Tunnel-Statistik (Summe über alle Peers).
    struct TunnelStats: Sendable, Equatable {
        var rxBytes: UInt64
        var txBytes: UInt64
        var lastHandshake: Date?
    }

    /// Fragt die NE per `sendProviderMessage("stats")` nach der Runtime-Config
    /// (wg-uapi-Format) und parst rx/tx/Handshake heraus. `nil`, wenn der
    /// Tunnel nicht läuft oder die NE nicht antwortet.
    func fetchStats(tunnelID id: UUID) async -> TunnelStats? {
        guard let session = managers[id]?.connection as? NETunnelProviderSession else { return nil }
        return await withCheckedContinuation { (cont: CheckedContinuation<TunnelStats?, Never>) in
            do {
                try session.sendProviderMessage(Data("stats".utf8)) { response in
                    cont.resume(returning: Self.parseStats(response))
                }
            } catch {
                cont.resume(returning: nil)
            }
        }
    }

    /// Parst das wg-uapi-Settings-Format (`key=value`-Zeilen) zu `TunnelStats`.
    private static func parseStats(_ data: Data?) -> TunnelStats? {
        guard let data, let text = String(data: data, encoding: .utf8) else { return nil }
        var rx: UInt64 = 0, tx: UInt64 = 0
        var handshake: TimeInterval = 0
        for line in text.split(separator: "\n") {
            guard let eq = line.firstIndex(of: "=") else { continue }
            let key = line[..<eq]
            let value = line[line.index(after: eq)...]
            switch key {
            case "rx_bytes": rx += UInt64(value) ?? 0
            case "tx_bytes": tx += UInt64(value) ?? 0
            case "last_handshake_time_sec": handshake = max(handshake, Double(value) ?? 0)
            default: break
            }
        }
        return TunnelStats(
            rxBytes: rx,
            txBytes: tx,
            lastHandshake: handshake > 0 ? Date(timeIntervalSince1970: handshake) : nil
        )
    }

    // MARK: - Helpers

    private func recordStatus(for manager: NETunnelProviderManager) {
        guard let id = Self.tunnelID(of: manager) else { return }
        statuses[id] = manager.connection.status
    }

    private static func tunnelID(of manager: NETunnelProviderManager) -> UUID? {
        guard let proto = manager.protocolConfiguration as? NETunnelProviderProtocol,
              let providerConfig = proto.providerConfiguration,
              let idString = providerConfig["tunnelID"] as? String,
              let id = UUID(uuidString: idString) else {
            return nil
        }
        return id
    }
}
