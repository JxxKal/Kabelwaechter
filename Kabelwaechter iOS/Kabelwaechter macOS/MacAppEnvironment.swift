import Foundation
import Observation
import KabelwaechterCore
import KabelwaechterPersistence

/// App-weite Abhängigkeiten der macOS-App. Milestone A hält nur die
/// `TunnelRepository`-Referenz (CloudKit-gesynct, geteilt mit iOS/tvOS).
/// Ein `TunnelManager` (NETunnelProviderManager + macOS-NE) kommt in
/// Milestone B dazu.
@MainActor
@Observable
final class MacAppEnvironment {

    let repository: any TunnelRepositoring

    init(repository: any TunnelRepositoring) {
        self.repository = repository
    }

    /// Production: SwiftData-`ModelContainer` mit CloudKit-Private-Database
    /// (gleicher Container wie iOS/tvOS). macOS ist nie ein Simulator —
    /// der signierte Build mit iCloud-Entitlement initialisiert CloudKit sauber.
    @MainActor
    static func makeProduction() throws -> MacAppEnvironment {
        let container = try TunnelContainers.makeTunnelContainer(
            cloudKitContainerID: KabelwaechterConstants.iCloudContainerIdentifier
        )
        return MacAppEnvironment(repository: TunnelRepository(container: container))
    }

    @MainActor
    static func makePreview() -> MacAppEnvironment {
        MacAppEnvironment(repository: InMemoryTunnelRepository())
    }
}
