import Testing
import SwiftData
@testable import KabelwaechterPersistence

@Suite("CloudKit schema probe")
struct CloudKitSchemaProbe {
    @Test("StoredTunnel-Container mit CloudKit-Config lässt sich bauen")
    func cloudKitContainerBuilds() throws {
        let config = ModelConfiguration(
            "tunnels",
            cloudKitDatabase: .private("iCloud.de.jankaluza.kabelwaechter.tunnels")
        )
        _ = try ModelContainer(for: StoredTunnel.self, configurations: config)
    }
}
