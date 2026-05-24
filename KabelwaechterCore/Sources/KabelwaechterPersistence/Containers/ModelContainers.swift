import Foundation
import SwiftData

/// Factory für den `ModelContainer`, in dem `StoredTunnel` persistiert und
/// (optional) via CloudKit synchronisiert wird. Seit ADR-0003 gibt es nur
/// noch **einen** Container — der frühere Template/Instance-Split (ADR-0001)
/// wurde aufgegeben, weil jetzt der komplette Tunnel inkl. Key syncen soll.
public enum TunnelContainers {

    /// Container für `StoredTunnel`. CloudKit-Sync ist optional und orientiert
    /// sich an Decision #12 (P2 — iCloud-optional, lokal-zuerst): ohne
    /// `cloudKitContainerID` läuft der Container rein lokal.
    /// - Parameters:
    ///   - cloudKitContainerID: Der iCloud-Container-Identifier (z.B. aus
    ///     `KabelwaechterConstants.iCloudContainerIdentifier`) — oder `nil`
    ///     für Local-Only-Modus (Simulator-Builds ohne signed entitlements,
    ///     User ohne iCloud-Account, …).
    ///   - isInMemory: `true` für Tests/Previews — schreibt nichts auf die
    ///     Platte und syncht nicht.
    public static func makeTunnelContainer(
        cloudKitContainerID: String?,
        isInMemory: Bool = false
    ) throws -> ModelContainer {
        let configuration: ModelConfiguration
        if isInMemory {
            configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        } else if let cloudKitContainerID {
            configuration = ModelConfiguration(
                "tunnels",
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .private(cloudKitContainerID)
            )
        } else {
            configuration = ModelConfiguration(
                "tunnels",
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .none
            )
        }
        return try ModelContainer(
            for: StoredTunnel.self,
            configurations: configuration
        )
    }
}
