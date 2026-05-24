import Foundation
import KabelwaechterCore

/// In-Memory-Implementierung von `TunnelRepositoring`. Hält Tunnel in
/// Dictionaries, ohne SwiftData/CloudKit. Für SwiftUI-Previews und für
/// schnelle Unit-Tests, die das Repository-Verhalten verifizieren, ohne
/// einen `ModelContainer` hochzufahren.
@MainActor
public final class InMemoryTunnelRepository: TunnelRepositoring {

    private struct Record {
        var template: TunnelTemplate
        var instance: TunnelInstance?
    }

    private var records: [UUID: Record] = [:]
    private let keychain: any KeychainStoring

    public init(keychain: any KeychainStoring = InMemoryKeychainStore()) {
        self.keychain = keychain
    }

    public func importWgQuick(_ wgQuickConfig: String, named name: String) throws -> UUID {
        let parsed: TunnelConfiguration
        do {
            parsed = try TunnelConfiguration(fromWgQuickConfig: wgQuickConfig, called: name)
        } catch let error as TunnelConfiguration.ParseError {
            throw TunnelRepositoryError.invalidWgQuickConfig(String(describing: error))
        }
        let tunnelID = UUID()
        let (template, instance, privateKey) = try parsed.splitForPersistence(tunnelID: tunnelID)
        if template.name.isEmpty { template.name = name }
        try keychain.storePrivateKey(privateKey, forTunnelID: tunnelID.uuidString)
        records[tunnelID] = Record(template: template, instance: instance)
        return tunnelID
    }

    public func allTunnels() throws -> [TunnelView] {
        records.values.map { record in
            let hasKey = (try? keychain.loadPrivateKey(forTunnelID: record.template.id.uuidString)) != nil
            return TunnelView(
                id: record.template.id,
                name: record.template.name,
                isConfiguredHere: record.instance != nil && hasKey,
                serverEndpoint: record.template.serverEndpoint,
                createdAt: record.template.createdAt
            )
        }
    }

    public func tunnel(id: UUID) throws -> TunnelView {
        guard let record = records[id] else {
            throw TunnelRepositoryError.tunnelNotFound
        }
        let hasKey = (try? keychain.loadPrivateKey(forTunnelID: id.uuidString)) != nil
        return TunnelView(
            id: record.template.id,
            name: record.template.name,
            isConfiguredHere: record.instance != nil && hasKey,
            serverEndpoint: record.template.serverEndpoint,
            createdAt: record.template.createdAt
        )
    }

    public func tunnelConfiguration(id: UUID) throws -> TunnelConfiguration {
        guard let record = records[id] else {
            throw TunnelRepositoryError.tunnelNotFound
        }
        guard let instance = record.instance else {
            throw TunnelRepositoryError.notConfiguredOnThisDevice
        }
        let privateKey: Data
        do {
            privateKey = try keychain.loadPrivateKey(forTunnelID: id.uuidString)
        } catch {
            throw TunnelRepositoryError.notConfiguredOnThisDevice
        }
        return TunnelConfiguration(template: record.template, instance: instance, privateKey: privateKey)
    }

    public func deleteTunnel(id: UUID) throws {
        records.removeValue(forKey: id)
        try? keychain.deletePrivateKey(forTunnelID: id.uuidString)
    }

    public func attachInstance(toTunnelID id: UUID, wgQuickConfig: String) throws {
        guard var record = records[id] else {
            throw TunnelRepositoryError.tunnelNotFound
        }
        let parsed: TunnelConfiguration
        do {
            parsed = try TunnelConfiguration(fromWgQuickConfig: wgQuickConfig)
        } catch let error as TunnelConfiguration.ParseError {
            throw TunnelRepositoryError.invalidWgQuickConfig(String(describing: error))
        }
        guard parsed.peers.count <= 1 else {
            throw TunnelRepositoryError.multiPeerNotSupported
        }
        record.instance = TunnelInstance(
            templateID: id,
            addresses: parsed.interface.addresses.map { $0.stringRepresentation },
            listenPort: parsed.interface.listenPort.map { Int($0) }
        )
        records[id] = record
        try keychain.storePrivateKey(parsed.interface.privateKey, forTunnelID: id.uuidString)
    }
}
