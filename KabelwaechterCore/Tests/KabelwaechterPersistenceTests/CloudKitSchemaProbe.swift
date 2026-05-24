import Testing
import SwiftData
@testable import KabelwaechterPersistence

@Suite("CloudKit schema probe")
struct CloudKitSchemaProbe {
    @Test("TunnelTemplate-Container mit CloudKit-Config lässt sich bauen")
    func cloudKitContainerBuilds() throws {
        let config = ModelConfiguration(
            "templates",
            cloudKitDatabase: .private("iCloud.de.jankaluza.kabelwaechter.tunnels")
        )
        _ = try ModelContainer(for: TunnelTemplate.self, configurations: config)
    }
}
