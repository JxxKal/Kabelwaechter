import Testing
import Foundation
import SwiftData
@testable import KabelwaechterCore
@testable import KabelwaechterPersistence

/// Tests gegen das `TunnelRepositoring`-Protokoll. Laufen gegen
/// `InMemoryTunnelRepository` UND gegen das echte `TunnelRepository` mit
/// einem In-Memory-ModelContainer — so verifizieren wir, dass beide
/// Implementierungen denselben Vertrag erfüllen.
@MainActor
@Suite("TunnelRepository (Protocol-Contract)")
struct TunnelRepositoryTests {

    static let validConfig = """
    [Interface]
    PrivateKey = qF1iY/zCm7XlGqXyDcUiPDV3rPdaYzVxq1jM5W3PJ2c=
    Address = 10.0.0.5/32
    DNS = 1.1.1.1
    ListenPort = 51820
    MTU = 1280

    [Peer]
    PublicKey = AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEE=
    AllowedIPs = 0.0.0.0/0, ::/0
    Endpoint = vpn.example.com:51820
    PersistentKeepalive = 25
    """

    static let secondConfig = """
    [Interface]
    PrivateKey = WB7P2H8tBp3y4LKVxFZK0sGn6Tn+RrjwzN5sZeY+y3I=
    Address = 10.0.0.6/32

    [Peer]
    PublicKey = AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEE=
    AllowedIPs = 0.0.0.0/0
    Endpoint = vpn.example.com:51820
    """

    // MARK: - Repository-Factories für die zwei Implementierungen

    private static func makeInMemoryRepo() -> any TunnelRepositoring {
        InMemoryTunnelRepository()
    }

    private static func makeSwiftDataRepo() throws -> any TunnelRepositoring {
        let container = try TunnelContainers.makeTunnelContainer(
            cloudKitContainerID: "iCloud.test",
            isInMemory: true
        )
        return TunnelRepository(container: container)
    }

    // MARK: - Tests

    @Test("Import: wg-quick landet als StoredTunnel inkl. Key (InMemory)")
    func importStores_inMemory() throws {
        try assertImportStores(repo: Self.makeInMemoryRepo())
    }

    @Test("Import: wg-quick landet als StoredTunnel inkl. Key (SwiftData)")
    func importStores_swiftData() throws {
        try assertImportStores(repo: try Self.makeSwiftDataRepo())
    }

    private func assertImportStores(repo: any TunnelRepositoring) throws {
        let id = try repo.importWgQuick(Self.validConfig, named: "Heimnetz")
        let view = try repo.tunnel(id: id)
        #expect(view.name == "Heimnetz")
        #expect(view.isConfiguredHere == true)
        #expect(view.serverEndpoint == "vpn.example.com:51820")
    }

    @Test("Round-trip: import → tunnelConfiguration ergibt äquivalente Felder (InMemory)")
    func roundtrip_inMemory() throws {
        try assertRoundtrip(repo: Self.makeInMemoryRepo())
    }

    @Test("Round-trip: import → tunnelConfiguration ergibt äquivalente Felder (SwiftData)")
    func roundtrip_swiftData() throws {
        try assertRoundtrip(repo: try Self.makeSwiftDataRepo())
    }

    private func assertRoundtrip(repo: any TunnelRepositoring) throws {
        let id = try repo.importWgQuick(Self.validConfig, named: "Heimnetz")
        let config = try repo.tunnelConfiguration(id: id)
        #expect(config.name == "Heimnetz")
        #expect(config.interface.privateKey.count == 32)
        #expect(config.interface.addresses.map { $0.stringRepresentation } == ["10.0.0.5/32"])
        #expect(config.interface.listenPort == 51820)
        #expect(config.interface.mtu == 1280)
        #expect(config.peers.count == 1)
        #expect(config.peers[0].endpoint?.stringRepresentation == "vpn.example.com:51820")
        #expect(config.peers[0].persistentKeepAlive == 25)
        #expect(config.peers[0].allowedIPs.count == 2)
    }

    @Test("delete entfernt Tunnel komplett (InMemory)")
    func deleteRemoves_inMemory() throws {
        try assertDeleteRemoves(repo: Self.makeInMemoryRepo())
    }

    @Test("delete entfernt Tunnel komplett (SwiftData)")
    func deleteRemoves_swiftData() throws {
        try assertDeleteRemoves(repo: try Self.makeSwiftDataRepo())
    }

    private func assertDeleteRemoves(repo: any TunnelRepositoring) throws {
        let id = try repo.importWgQuick(Self.validConfig, named: "T")
        try repo.deleteTunnel(id: id)

        #expect(throws: TunnelRepositoryError.tunnelNotFound) {
            _ = try repo.tunnel(id: id)
        }
        let all = try repo.allTunnels()
        #expect(all.isEmpty)
    }

    @Test("allTunnels listet mehrere Tunnel (SwiftData)")
    func allTunnels_listsMultiple() throws {
        let repo = try Self.makeSwiftDataRepo()
        _ = try repo.importWgQuick(Self.validConfig, named: "A")
        _ = try repo.importWgQuick(Self.secondConfig, named: "B")
        let all = try repo.allTunnels()
        #expect(all.count == 2)
        #expect(Set(all.map { $0.name }) == ["A", "B"])
    }

    @Test("tunnelConfiguration auf unbekannte TunnelID wirft tunnelNotFound")
    func tunnelConfiguration_unknown() throws {
        let repo = Self.makeInMemoryRepo()
        #expect(throws: TunnelRepositoryError.tunnelNotFound) {
            _ = try repo.tunnelConfiguration(id: UUID())
        }
    }

    @Test("Multi-Peer wird abgewiesen")
    func multiPeerRejected() throws {
        let multiPeer = """
        [Interface]
        PrivateKey = qF1iY/zCm7XlGqXyDcUiPDV3rPdaYzVxq1jM5W3PJ2c=

        [Peer]
        PublicKey = AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEE=
        AllowedIPs = 10.0.0.0/24

        [Peer]
        PublicKey = BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBEE=
        AllowedIPs = 10.0.1.0/24
        """
        let repo = Self.makeInMemoryRepo()
        #expect(throws: TunnelRepositoryError.multiPeerNotSupported) {
            _ = try repo.importWgQuick(multiPeer, named: "Multi")
        }
    }
}
