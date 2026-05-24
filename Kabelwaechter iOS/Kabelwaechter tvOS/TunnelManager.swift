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
    }

    /// Status für einen bestimmten Tunnel — vor `refresh()` aufgerufen liefert
    /// `nil`, das die UI als "unbekannt" interpretieren kann.
    func status(forTunnelID id: UUID) -> NEVPNStatus? {
        statuses[id]
    }

    /// Baut die NEVPNManager-Konfiguration auf (anlegen oder updaten) und
    /// startet den Tunnel. Wirft, wenn die Tunnel-UUID im Repository
    /// nicht auflösbar ist (z.B. lokaler Tunnel-Instance fehlt).
    func connect(tunnelID id: UUID, displayName: String) async throws {
        let config = try repository.tunnelConfiguration(id: id)
        let wgQuick = config.asWgQuickConfig()

        let manager = managers[id] ?? NETunnelProviderManager()
        let proto = (manager.protocolConfiguration as? NETunnelProviderProtocol) ?? NETunnelProviderProtocol()
        proto.providerBundleIdentifier = providerBundleIdentifier
        // serverAddress muss laut Apple-Doku non-empty sein, sonst lehnt
        // NEVPNManager.saveToPreferences ab. Wir nehmen den Server-Endpoint
        // aus der Config — bei generischen Tunneln tut's auch ein Platzhalter.
        proto.serverAddress = config.peers.first?.endpoint?.stringRepresentation ?? "kabelwaechter"
        proto.providerConfiguration = [
            "wgQuickConfig": wgQuick,
            "tunnelID": id.uuidString
        ]

        manager.protocolConfiguration = proto
        manager.localizedDescription = displayName
        manager.isEnabled = true

        try await manager.saveToPreferences()
        // Nach saveToPreferences müssen wir loadFromPreferences aufrufen,
        // sonst lehnt startVPNTunnel mit "configuration is invalid" ab —
        // Apple-Quirk, dokumentiert in NEVPNManager.h.
        try await manager.loadFromPreferences()

        managers[id] = manager
        try manager.connection.startVPNTunnel()
        statuses[id] = manager.connection.status
    }

    /// Stoppt einen aktiven Tunnel. No-op wenn kein Manager existiert.
    func disconnect(tunnelID id: UUID) {
        managers[id]?.connection.stopVPNTunnel()
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
