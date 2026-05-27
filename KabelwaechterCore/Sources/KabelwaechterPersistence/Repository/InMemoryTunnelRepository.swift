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

    public func importWgQuick(_ wgQuickConfig: String, named name: String, target: TunnelTarget) throws -> UUID {
        let parsed: TunnelConfiguration
        do {
            parsed = try TunnelConfiguration(fromWgQuickConfig: wgQuickConfig, called: name)
        } catch let error as TunnelConfiguration.ParseError {
            throw TunnelRepositoryError.invalidWgQuickConfig(String(describing: error))
        }
        let tunnelID = UUID()
        let stored = try parsed.toStoredTunnel(tunnelID: tunnelID)
        if stored.name.isEmpty { stored.name = name }
        stored.target = target
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
        guard let existing = tunnels[id] else {
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
        fresh.target = existing.target // Ziel bleibt beim Bearbeiten erhalten
        fresh.ownerDeviceID = existing.ownerDeviceID // Geräte-Zuweisung erhalten
        fresh.ownerDeviceName = existing.ownerDeviceName
        tunnels[id] = fresh
    }

    public func setTarget(_ target: TunnelTarget, forTunnelID id: UUID) throws {
        guard let stored = tunnels[id] else {
            throw TunnelRepositoryError.tunnelNotFound
        }
        stored.target = target
    }

    public func assign(tunnelID id: UUID, toDeviceID deviceID: String, named deviceName: String) throws {
        guard let stored = tunnels[id] else {
            throw TunnelRepositoryError.tunnelNotFound
        }
        stored.ownerDeviceID = deviceID
        stored.ownerDeviceName = deviceName
    }

    public func freeTunnel(id: UUID) throws {
        guard let stored = tunnels[id] else {
            throw TunnelRepositoryError.tunnelNotFound
        }
        stored.ownerDeviceID = nil
        stored.ownerDeviceName = nil
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
            createdAt: stored.createdAt,
            target: stored.target,
            ownerDeviceID: stored.ownerDeviceID,
            ownerDeviceName: stored.ownerDeviceName
        )
    }
}
