import Foundation
import KabelwaechterCore

/// In-Memory-Implementierung von `TunnelRepositoring`. Hält Tunnel in einem
/// Dictionary, ohne SwiftData/CloudKit. Für SwiftUI-Previews und für schnelle
/// Unit-Tests, die das Repository-Verhalten verifizieren, ohne einen
/// `ModelContainer` hochzufahren.
@MainActor
public final class InMemoryTunnelRepository: TunnelRepositoring {

    private var tunnels: [UUID: StoredTunnel] = [:]

    public init() {}

    public func importWgQuick(_ wgQuickConfig: String, named name: String) throws -> UUID {
        let parsed: TunnelConfiguration
        do {
            parsed = try TunnelConfiguration(fromWgQuickConfig: wgQuickConfig, called: name)
        } catch let error as TunnelConfiguration.ParseError {
            throw TunnelRepositoryError.invalidWgQuickConfig(String(describing: error))
        }
        let tunnelID = UUID()
        let stored = try parsed.toStoredTunnel(tunnelID: tunnelID)
        if stored.name.isEmpty { stored.name = name }
        if !stored.serverPublicKey.isEmpty {
            let addrs = Set(stored.addresses)
            if let existing = tunnels.values.first(where: {
                $0.serverPublicKey == stored.serverPublicKey && Set($0.addresses) == addrs
            }) {
                throw TunnelRepositoryError.duplicate(existingName: existing.name)
            }
        }
        tunnels[tunnelID] = stored
        return tunnelID
    }

    public func updateTunnel(id: UUID, name: String, wgQuickConfig: String) throws {
        guard tunnels[id] != nil else {
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
        if !trimmed.isEmpty { fresh.name = trimmed }
        tunnels[id] = fresh
    }

    public func allTunnels() throws -> [TunnelView] {
        tunnels.values.map(Self.view(of:))
    }

    public func tunnel(id: UUID) throws -> TunnelView {
        guard let stored = tunnels[id] else {
            throw TunnelRepositoryError.tunnelNotFound
        }
        return Self.view(of: stored)
    }

    public func tunnelConfiguration(id: UUID) throws -> TunnelConfiguration {
        guard let stored = tunnels[id] else {
            throw TunnelRepositoryError.tunnelNotFound
        }
        guard !stored.privateKey.isEmpty else {
            throw TunnelRepositoryError.notConfiguredOnThisDevice
        }
        return TunnelConfiguration(stored: stored)
    }

    public func deleteTunnel(id: UUID) throws {
        tunnels.removeValue(forKey: id)
    }

    private static func view(of stored: StoredTunnel) -> TunnelView {
        TunnelView(
            id: stored.id,
            name: stored.name,
            isConfiguredHere: !stored.privateKey.isEmpty,
            serverEndpoint: stored.serverEndpoint,
            createdAt: stored.createdAt
        )
    }
}
