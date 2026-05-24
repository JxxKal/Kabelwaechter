import Foundation
import SwiftData
import KabelwaechterCore

/// SwiftData-Implementierung von `TunnelRepositoring`. Operiert auf zwei
/// `ModelContainer`n (Cloud-Template + Local-Instance) und einem
/// `KeychainStoring`.
///
/// `@MainActor`-isoliert, weil `ModelContext` nicht `Sendable` ist und
/// SwiftUI ohnehin auf dem Main-Actor lebt. Phase 2.3 braucht kein
/// `@ModelActor` — DB-Operationen sind hier billig.
@MainActor
public final class TunnelRepository: TunnelRepositoring {

    private let templateContext: ModelContext
    private let instanceContext: ModelContext
    private let keychain: any KeychainStoring

    public init(
        templateContainer: ModelContainer,
        instanceContainer: ModelContainer,
        keychain: any KeychainStoring
    ) {
        self.templateContext = ModelContext(templateContainer)
        self.instanceContext = ModelContext(instanceContainer)
        self.keychain = keychain
    }

    // MARK: - Import

    public func importWgQuick(_ wgQuickConfig: String, named name: String) throws -> UUID {
        let parsed: TunnelConfiguration
        do {
            parsed = try TunnelConfiguration(fromWgQuickConfig: wgQuickConfig, called: name)
        } catch let error as TunnelConfiguration.ParseError {
            throw TunnelRepositoryError.invalidWgQuickConfig(String(describing: error))
        }

        let tunnelID = UUID()
        let (template, instance, privateKey) = try parsed.splitForPersistence(tunnelID: tunnelID)
        // Falls der Parser den Namen nicht gesetzt hat (init named: nil),
        // sorgt der explizite `name`-Parameter dafür, dass die Liste etwas zeigt.
        if template.name.isEmpty { template.name = name }

        templateContext.insert(template)
        instanceContext.insert(instance)
        try keychain.storePrivateKey(privateKey, forTunnelID: tunnelID.uuidString)
        try templateContext.save()
        try instanceContext.save()
        return tunnelID
    }

    // MARK: - Reads

    public func allTunnels() throws -> [TunnelView] {
        let templates = try templateContext.fetch(FetchDescriptor<TunnelTemplate>())
        let instances = try instanceContext.fetch(FetchDescriptor<TunnelInstance>())
        let instanceIDs = Set(instances.map { $0.templateID })

        return templates.map { template in
            let hasInstance = instanceIDs.contains(template.id)
            let hasKey = (try? keychain.loadPrivateKey(forTunnelID: template.id.uuidString)) != nil
            return TunnelView(
                id: template.id,
                name: template.name,
                isConfiguredHere: hasInstance && hasKey,
                serverEndpoint: template.serverEndpoint,
                createdAt: template.createdAt
            )
        }
    }

    public func tunnel(id: UUID) throws -> TunnelView {
        guard let template = try fetchTemplate(id: id) else {
            throw TunnelRepositoryError.tunnelNotFound
        }
        let hasInstance = try fetchInstance(templateID: id) != nil
        let hasKey = (try? keychain.loadPrivateKey(forTunnelID: id.uuidString)) != nil
        return TunnelView(
            id: template.id,
            name: template.name,
            isConfiguredHere: hasInstance && hasKey,
            serverEndpoint: template.serverEndpoint,
            createdAt: template.createdAt
        )
    }

    public func tunnelConfiguration(id: UUID) throws -> TunnelConfiguration {
        guard let template = try fetchTemplate(id: id) else {
            throw TunnelRepositoryError.tunnelNotFound
        }
        guard let instance = try fetchInstance(templateID: id) else {
            throw TunnelRepositoryError.notConfiguredOnThisDevice
        }
        let privateKey: Data
        do {
            privateKey = try keychain.loadPrivateKey(forTunnelID: id.uuidString)
        } catch {
            throw TunnelRepositoryError.notConfiguredOnThisDevice
        }
        return TunnelConfiguration(template: template, instance: instance, privateKey: privateKey)
    }

    // MARK: - Mutations

    public func deleteTunnel(id: UUID) throws {
        if let template = try fetchTemplate(id: id) {
            templateContext.delete(template)
        }
        if let instance = try fetchInstance(templateID: id) {
            instanceContext.delete(instance)
        }
        try? keychain.deletePrivateKey(forTunnelID: id.uuidString)
        try templateContext.save()
        try instanceContext.save()
    }

    public func attachInstance(toTunnelID id: UUID, wgQuickConfig: String) throws {
        guard try fetchTemplate(id: id) != nil else {
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
        // Bestehende Instance auf dem Gerät überschreiben — User hat
        // explizit eine neue Config eingelesen.
        if let existing = try fetchInstance(templateID: id) {
            instanceContext.delete(existing)
        }
        let newInstance = TunnelInstance(
            templateID: id,
            addresses: parsed.interface.addresses.map { $0.stringRepresentation },
            listenPort: parsed.interface.listenPort.map { Int($0) }
        )
        instanceContext.insert(newInstance)
        try keychain.storePrivateKey(parsed.interface.privateKey, forTunnelID: id.uuidString)
        try instanceContext.save()
    }

    // MARK: - Helpers

    private func fetchTemplate(id: UUID) throws -> TunnelTemplate? {
        var descriptor = FetchDescriptor<TunnelTemplate>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try templateContext.fetch(descriptor).first
    }

    private func fetchInstance(templateID: UUID) throws -> TunnelInstance? {
        var descriptor = FetchDescriptor<TunnelInstance>(
            predicate: #Predicate { $0.templateID == templateID }
        )
        descriptor.fetchLimit = 1
        return try instanceContext.fetch(descriptor).first
    }
}
