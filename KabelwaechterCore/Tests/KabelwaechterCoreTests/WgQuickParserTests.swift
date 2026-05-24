import Testing
import Foundation
import Network
@testable import KabelwaechterCore

/// Tests für den wg-quick-Config-Parser. Fixtures sind reale wg-quick-Configs
/// (mit synthetischen Keys — base64, 32 Byte). Die Parser-Semantik orientiert
/// sich an WireGuardKit/Shared/Model/TunnelConfiguration+WgQuickConfig.swift
/// (MIT, WireGuard LLC), portiert auf Core-Typen ohne WireGuardKit-Abhängigkeit.
@Suite("wg-quick parser")
struct WgQuickParserTests {

    // Synthetische 32-Byte-Keys (base64). Echte WG-Keys haben dieselbe Form.
    static let privA = "qF1iY/zCm7XlGqXyDcUiPDV3rPdaYzVxq1jM5W3PJ2c="
    static let privB = "WB7P2H8tBp3y4LKVxFZK0sGn6Tn+RrjwzN5sZeY+y3I="
    static let pubA = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEE="
    static let pubB = "BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBEE="
    static let psk = "/V3Dt3GpD06bRpUaJqV/+r4DGdsHX2KCi5OWVHM/IUE="

    // MARK: - Happy paths

    @Test("Minimal: nur [Interface] mit PrivateKey")
    func minimalInterface() throws {
        let config = """
        [Interface]
        PrivateKey = \(Self.privA)
        """
        let tunnel = try TunnelConfiguration(fromWgQuickConfig: config, called: "minimal")
        #expect(tunnel.name == "minimal")
        #expect(tunnel.interface.privateKey.base64EncodedString() == Self.privA)
        #expect(tunnel.interface.privateKey.count == 32)
        #expect(tunnel.peers.isEmpty)
    }

    @Test("[Interface] mit allen Optionen")
    func fullInterface() throws {
        let config = """
        [Interface]
        PrivateKey = \(Self.privA)
        Address = 10.0.0.2/32, fd00::2/128
        DNS = 1.1.1.1, example.com
        ListenPort = 51820
        MTU = 1280
        """
        let tunnel = try TunnelConfiguration(fromWgQuickConfig: config)
        #expect(tunnel.interface.addresses.count == 2)
        #expect(tunnel.interface.addresses[0].stringRepresentation == "10.0.0.2/32")
        #expect(tunnel.interface.addresses[1].stringRepresentation == "fd00::2/128")
        #expect(tunnel.interface.dns.count == 1)
        #expect(tunnel.interface.dnsSearch == ["example.com"])
        #expect(tunnel.interface.listenPort == 51820)
        #expect(tunnel.interface.mtu == 1280)
    }

    @Test("[Interface] + ein [Peer]")
    func singlePeer() throws {
        let config = """
        [Interface]
        PrivateKey = \(Self.privA)

        [Peer]
        PublicKey = \(Self.pubA)
        AllowedIPs = 0.0.0.0/0, ::/0
        Endpoint = vpn.example.com:51820
        PersistentKeepalive = 25
        """
        let tunnel = try TunnelConfiguration(fromWgQuickConfig: config)
        #expect(tunnel.peers.count == 1)
        let peer = tunnel.peers[0]
        #expect(peer.publicKey.base64EncodedString() == Self.pubA)
        #expect(peer.allowedIPs.count == 2)
        #expect(peer.endpoint?.stringRepresentation == "vpn.example.com:51820")
        #expect(peer.persistentKeepAlive == 25)
        #expect(peer.preSharedKey == nil)
    }

    @Test("Zwei [Peer] mit unterschiedlichen Public Keys")
    func twoPeers() throws {
        let config = """
        [Interface]
        PrivateKey = \(Self.privA)

        [Peer]
        PublicKey = \(Self.pubA)
        AllowedIPs = 10.0.0.0/24

        [Peer]
        PublicKey = \(Self.pubB)
        AllowedIPs = 10.0.1.0/24
        PresharedKey = \(Self.psk)
        """
        let tunnel = try TunnelConfiguration(fromWgQuickConfig: config)
        #expect(tunnel.peers.count == 2)
        #expect(tunnel.peers[0].publicKey.base64EncodedString() == Self.pubA)
        #expect(tunnel.peers[1].publicKey.base64EncodedString() == Self.pubB)
        #expect(tunnel.peers[1].preSharedKey?.base64EncodedString() == Self.psk)
    }

    @Test("Mehrere Address-Zeilen werden zusammengeführt")
    func multipleAddressLines() throws {
        let config = """
        [Interface]
        PrivateKey = \(Self.privA)
        Address = 10.0.0.2/32
        Address = fd00::2/128
        """
        let tunnel = try TunnelConfiguration(fromWgQuickConfig: config)
        #expect(tunnel.interface.addresses.count == 2)
    }

    @Test("Kommentare und Leerzeilen werden ignoriert")
    func commentsAndBlankLines() throws {
        let config = """
        # This is a comment
        [Interface]
        # privatekey below
        PrivateKey = \(Self.privA) # inline comment

        [Peer]
        PublicKey = \(Self.pubA)
        """
        let tunnel = try TunnelConfiguration(fromWgQuickConfig: config)
        #expect(tunnel.interface.privateKey.base64EncodedString() == Self.privA)
        #expect(tunnel.peers.count == 1)
    }

    @Test("Round-trip: parse → asWgQuickConfig → parse ergibt gleichen Tunnel")
    func roundTrip() throws {
        let config = """
        [Interface]
        PrivateKey = \(Self.privA)
        Address = 10.0.0.2/32
        ListenPort = 51820

        [Peer]
        PublicKey = \(Self.pubA)
        AllowedIPs = 0.0.0.0/0
        Endpoint = 1.2.3.4:51820
        """
        let first = try TunnelConfiguration(fromWgQuickConfig: config)
        let serialized = first.asWgQuickConfig()
        let second = try TunnelConfiguration(fromWgQuickConfig: serialized)
        #expect(first.interface.privateKey == second.interface.privateKey)
        #expect(first.interface.addresses == second.interface.addresses)
        #expect(first.interface.listenPort == second.interface.listenPort)
        #expect(first.peers.count == second.peers.count)
        #expect(first.peers[0].publicKey == second.peers[0].publicKey)
        #expect(first.peers[0].endpoint == second.peers[0].endpoint)
    }

    // MARK: - Error paths

    @Test("Fehlt [Interface], wirft noInterface")
    func missingInterface() {
        let config = """
        [Peer]
        PublicKey = \(Self.pubA)
        """
        #expect(throws: TunnelConfiguration.ParseError.self) {
            try TunnelConfiguration(fromWgQuickConfig: config)
        }
    }

    @Test("Fehlt PrivateKey, wirft interfaceHasNoPrivateKey")
    func missingPrivateKey() {
        let config = """
        [Interface]
        Address = 10.0.0.2/32
        """
        #expect(throws: TunnelConfiguration.ParseError.self) {
            try TunnelConfiguration(fromWgQuickConfig: config)
        }
    }

    @Test("Invalides Base64 für PrivateKey wirft interfaceHasInvalidPrivateKey")
    func invalidPrivateKey() {
        let config = """
        [Interface]
        PrivateKey = !!!nicht-base64!!!
        """
        #expect(throws: TunnelConfiguration.ParseError.self) {
            try TunnelConfiguration(fromWgQuickConfig: config)
        }
    }

    @Test("Zwei [Peer] mit identischem PublicKey wirft multiplePeersWithSamePublicKey")
    func duplicatePeerPublicKey() {
        let config = """
        [Interface]
        PrivateKey = \(Self.privA)

        [Peer]
        PublicKey = \(Self.pubA)
        AllowedIPs = 10.0.0.0/24

        [Peer]
        PublicKey = \(Self.pubA)
        AllowedIPs = 10.0.1.0/24
        """
        #expect(throws: TunnelConfiguration.ParseError.self) {
            try TunnelConfiguration(fromWgQuickConfig: config)
        }
    }

    @Test("Zwei [Interface]-Sektionen wirft multipleInterfaces")
    func multipleInterfaces() {
        let config = """
        [Interface]
        PrivateKey = \(Self.privA)

        [Interface]
        PrivateKey = \(Self.privB)
        """
        #expect(throws: TunnelConfiguration.ParseError.self) {
            try TunnelConfiguration(fromWgQuickConfig: config)
        }
    }
}
