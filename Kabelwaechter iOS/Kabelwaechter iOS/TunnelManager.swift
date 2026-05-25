import Foundation
import Observation
import NetworkExtension
import KabelwaechterCore
import KabelwaechterPersistence

/// Wrapper über `NETunnelProviderManager` für die iOS-App. Identisch zur
/// tvOS-Variante — das iPhone kann seit der iOS-NE (Decision #8 revidiert)
/// eigene (`target == .phone`) Tunnel selbst aufbauen. Provider ist die
/// iOS-Network-Extension.
@MainActor
@Observable
final class TunnelManager {

    private(set) var statuses: [UUID: NEVPNStatus] = [:]
    private var managers: [UUID: NETunnelProviderManager] = [:]
    private let providerBundleIdentifier: String = KabelwaechterConstants.BundleIdentifiers.iOSNetworkExtension
    private let repository: any TunnelRepositoring
    private var statusObserver: NSObjectProtocol?

    init(repository: any TunnelRepositoring) {
        self.repository = repository
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

    /// Lädt alle Manager aus den System-Preferences und befüllt `statuses`.
    func refresh() async throws {
        let loaded = try await NETunnelProviderManager.loadAllFromPreferences()
        managers.removeAll()
        for manager in loaded {
            guard let id = Self.tunnelID(of: manager) else { continue }
            managers[id] = manager
            statuses[id] = manager.connection.status
        }
    }

    func status(forTunnelID id: UUID) -> NEVPNStatus? {
        statuses[id]
    }

    @discardableResult
    private func prepareManager(tunnelID id: UUID, displayName: String, onDemand: Bool?) async throws -> NETunnelProviderManager {
        let config = try repository.tunnelConfiguration(id: id)
        let wgQuick = config.asWgQuickConfig()

        let manager = managers[id] ?? NETunnelProviderManager()
        let proto = (manager.protocolConfiguration as? NETunnelProviderProtocol) ?? NETunnelProviderProtocol()
        proto.providerBundleIdentifier = providerBundleIdentifier
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
        try await manager.loadFromPreferences()
        managers[id] = manager
        return manager
    }

    func connect(tunnelID id: UUID, displayName: String) async throws {
        let manager = try await prepareManager(tunnelID: id, displayName: displayName, onDemand: nil)
        try manager.connection.startVPNTunnel()
        statuses[id] = manager.connection.status
    }

    func isAutoConnect(tunnelID id: UUID) -> Bool {
        managers[id]?.isOnDemandEnabled ?? false
    }

    func setAutoConnect(_ enabled: Bool, tunnelID id: UUID, displayName: String) async throws {
        let manager = try await prepareManager(tunnelID: id, displayName: displayName, onDemand: enabled)
        if enabled, manager.connection.status == .disconnected || manager.connection.status == .invalid {
            try manager.connection.startVPNTunnel()
        }
        statuses[id] = manager.connection.status
    }

    func disconnect(tunnelID id: UUID) async {
        guard let manager = managers[id] else { return }
        if manager.isOnDemandEnabled {
            manager.isOnDemandEnabled = false
            manager.onDemandRules = []
            try? await manager.saveToPreferences()
        }
        manager.connection.stopVPNTunnel()
    }

    // MARK: - Live-Statistiken

    struct TunnelStats: Sendable, Equatable {
        var rxBytes: UInt64
        var txBytes: UInt64
        var lastHandshake: Date?
    }

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
