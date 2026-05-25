import Foundation
import SwiftData
import KabelwaechterCore

/// SwiftData-Implementierung von `TunnelRepositoring`. Operiert auf **einem**
/// `ModelContainer` (`StoredTunnel`, optional CloudKit-gesynct). Der Private
/// Key lebt seit ADR-0003 im Modell selbst — kein separater Keychain mehr im
/// Repo-Pfad (die NE bekommt den Key ohnehin als wg-quick-String über
/// `providerConfiguration`, nicht aus dem Keychain).
///
/// `@MainActor`-isoliert, weil `ModelContext` nicht `Sendable` ist und
/// SwiftUI ohnehin auf dem Main-Actor lebt.
@MainActor
public final class TunnelRepository: TunnelRepositoring {

    private let context: ModelContext

    public init(container: ModelContainer) {
        self.context = ModelContext(container)
    }

    // MARK: - Import

    public func importWgQuick(_ wgQuickConfig: String, named name: String, target: TunnelTarget) throws -> UUID {
        let parsed: TunnelConfiguration
        do {
            parsed = try TunnelConfiguration(fromWgQuickConfig: wgQuickConfig, called: name)
        } catch let error as TunnelConfiguration.ParseError {
            throw TunnelRepositoryError.invalidWgQuickConfig(String(describing: error))
        }

        let tunnelID = UUID()
        let stored = try parsed.toStoredTunnel(tunnelID: tunnelID)
        // Falls der Parser den Namen nicht gesetzt hat (init named: nil),
        // sorgt der explizite `name`-Parameter dafür, dass die Liste etwas zeigt.
        if stored.name.isEmpty { stored.name = name }
        stored.target = target

        if let existing = try duplicate(of: stored) {
            throw TunnelRepositoryError.duplicate(existingName: existing.name)
        }

        context.insert(stored)
        try context.save()
        return tunnelID
    }

    public func setTarget(_ target: TunnelTarget, forTunnelID id: UUID) throws {
        guard let stored = try fetch(id: id) else {
            throw TunnelRepositoryError.tunnelNotFound
        }
        stored.target = target
        try context.save()
    }

    /// Sucht einen bereits vorhandenen Tunnel mit gleicher Peer-Identität
    /// (gleicher Server-PublicKey + gleiche Interface-Address-Menge).
    private func duplicate(of candidate: StoredTunnel) throws -> StoredTunnel? {
        guard !candidate.serverPublicKey.isEmpty else { return nil }
        let addrs = Set(candidate.addresses)
        return try context.fetch(FetchDescriptor<StoredTunnel>()).first {
            $0.serverPublicKey == candidate.serverPublicKey && Set($0.addresses) == addrs
        }
    }

    // MARK: - Update

    public func updateTunnel(id: UUID, name: String, wgQuickConfig: String) throws {
        guard let existing = try fetch(id: id) else {
            throw TunnelRepositoryError.tunnelNotFound
        }
        let parsed: TunnelConfiguration
        do {
            parsed = try TunnelConfiguration(fromWgQuickConfig: wgQuickConfig, called: name)
        } catch let error as TunnelConfiguration.ParseError {
            throw TunnelRepositoryError.invalidWgQuickConfig(String(describing: error))
        }
        let fresh = try parsed.toStoredTunnel(tunnelID: id)
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        existing.name = trimmed.isEmpty ? fresh.name : trimmed
        existing.addresses = fresh.addresses
        existing.privateKey = fresh.privateKey
        existing.listenPort = fresh.listenPort
        existing.dns = fresh.dns
        existing.mtu = fresh.mtu
        existing.serverPublicKey = fresh.serverPublicKey
        existing.serverEndpoint = fresh.serverEndpoint
        existing.allowedIPs = fresh.allowedIPs
        existing.presharedKey = fresh.presharedKey
        existing.persistentKeepalive = fresh.persistentKeepalive
        try context.save()
    }

    // MARK: - Reads

    public func allTunnels() throws -> [TunnelView] {
        let tunnels = try context.fetch(FetchDescriptor<StoredTunnel>())
        return tunnels.map(Self.view(of:))
    }

    public func tunnel(id: UUID) throws -> TunnelView {
        guard let stored = try fetch(id: id) else {
            throw TunnelRepositoryError.tunnelNotFound
        }
        return Self.view(of: stored)
    }

    public func tunnelConfiguration(id: UUID) throws -> TunnelConfiguration {
        guard let stored = try fetch(id: id) else {
            throw TunnelRepositoryError.tunnelNotFound
        }
        guard !stored.privateKey.isEmpty else {
            throw TunnelRepositoryError.notConfiguredOnThisDevice
        }
        return TunnelConfiguration(stored: stored)
    }

    // MARK: - Mutations

    public func deleteTunnel(id: UUID) throws {
        if let stored = try fetch(id: id) {
            context.delete(stored)
            try context.save()
        }
    }

    // MARK: - Helpers

    private func fetch(id: UUID) throws -> StoredTunnel? {
        var descriptor = FetchDescriptor<StoredTunnel>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private static func view(of stored: StoredTunnel) -> TunnelView {
        TunnelView(
            id: stored.id,
            name: stored.name,
            isConfiguredHere: !stored.privateKey.isEmpty,
            serverEndpoint: stored.serverEndpoint,
            createdAt: stored.createdAt,
            target: stored.target
        )
    }
}
