import Foundation
import SwiftData

/// Factories für die zwei `ModelContainer`, in denen TunnelTemplate (Cloud)
/// und TunnelInstance (lokal) getrennt persistiert werden. Siehe ADR-0001.
public enum TunnelContainers {

    /// Container für `TunnelTemplate` — mit CloudKit-Private-Database-Sync.
    /// - Parameters:
    ///   - cloudKitContainerID: Der iCloud-Container-Identifier aus
    ///     `KabelwaechterConstants.iCloudContainerIdentifier`. Wird vom
    ///     Aufrufer durchgereicht, damit Core nicht hart gegen die Konstante
    ///     bindet (Test-Setups können andere IDs übergeben).
    ///   - isInMemory: `true` für Tests/Previews — schreibt nichts auf die
    ///     Platte und syncht nicht.
    public static func makeCloudTemplateContainer(
        cloudKitContainerID: String,
        isInMemory: Bool = false
    ) throws -> ModelContainer {
        let configuration: ModelConfiguration
        if isInMemory {
            configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        } else {
            configuration = ModelConfiguration(
                "templates",
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .private(cloudKitContainerID)
            )
        }
        return try ModelContainer(
            for: TunnelTemplate.self,
            configurations: configuration
        )
    }

    /// Container für `TunnelInstance` — explizit **kein** CloudKit-Sync.
    /// Strukturelle Garantie, dass per-Device-Daten nicht in iCloud landen.
    public static func makeLocalInstanceContainer(
        isInMemory: Bool = false
    ) throws -> ModelContainer {
        let configuration: ModelConfiguration
        if isInMemory {
            configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        } else {
            configuration = ModelConfiguration(
                "instances",
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .none
            )
        }
        return try ModelContainer(
            for: TunnelInstance.self,
            configurations: configuration
        )
    }
}
