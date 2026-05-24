import Foundation
import SwiftData

/// Factories für die zwei `ModelContainer`, in denen TunnelTemplate (Cloud)
/// und TunnelInstance (lokal) getrennt persistiert werden. Siehe ADR-0001.
public enum TunnelContainers {

    /// Container für `TunnelTemplate`. CloudKit-Sync ist optional und
    /// orientiert sich an Decision #12 (P2 — iCloud-optional, lokal-zuerst):
    /// ohne `cloudKitContainerID` läuft der Container rein lokal.
    /// - Parameters:
    ///   - cloudKitContainerID: Der iCloud-Container-Identifier (z.B. aus
    ///     `KabelwaechterConstants.iCloudContainerIdentifier`) — oder `nil`
    ///     für Local-Only-Modus (Simulator-Builds ohne signed entitlements,
    ///     User ohne iCloud-Account, …).
    ///   - isInMemory: `true` für Tests/Previews — schreibt nichts auf die
    ///     Platte und syncht nicht.
    public static func makeCloudTemplateContainer(
        cloudKitContainerID: String?,
        isInMemory: Bool = false
    ) throws -> ModelContainer {
        let configuration: ModelConfiguration
        if isInMemory {
            configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        } else if let cloudKitContainerID {
            configuration = ModelConfiguration(
                "templates",
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .private(cloudKitContainerID)
            )
        } else {
            configuration = ModelConfiguration(
                "templates",
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .none
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
