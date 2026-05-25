import Testing
import Foundation
import SwiftData
@testable import KabelwaechterPersistence

@Suite("CloudKit schema probe")
struct CloudKitSchemaProbe {
    @Test("StoredTunnel-Container mit CloudKit-Config lässt sich bauen")
    func cloudKitContainerBuilds() throws {
        // CloudKit-Mirroring verlangt eine Bundle-ID. Im `swift test`-CLI-Prozess
        // ist die nil → `NSCloudKitMirroringDelegate` crasht beim dealloc
        // ("bundleIdentifier != nil"). Der Container darf dort also gar nicht
        // erst erzeugt werden. Sinnvoll prüfbar nur in einem gehosteten
        // Test-Target (mit App-Bundle).
        guard Bundle.main.bundleIdentifier != nil else { return }

        let config = ModelConfiguration(
            "tunnels",
            cloudKitDatabase: .private("iCloud.de.jankaluza.kabelwaechter.tunnels")
        )
        _ = try ModelContainer(for: StoredTunnel.self, configurations: config)
    }
}
