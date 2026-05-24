import Foundation
import KabelwaechterCore

/// Brücke zwischen der Core-Domäne (`TunnelConfiguration`) und der
/// Persistenz-Repräsentation (`StoredTunnel`).
///
/// Scope: nur Single-Peer-Tunnel (typischer VPN-Client-Fall). Multi-Peer wird
/// abgewiesen — siehe `TunnelRepositoryError.multiPeerNotSupported`.
extension TunnelConfiguration {

    /// Wandelt eine Core-`TunnelConfiguration` in ein persistierbares
    /// `StoredTunnel` (inkl. Private Key) um.
    /// - Throws: `TunnelRepositoryError.multiPeerNotSupported` bei mehr als
    ///   einem Peer.
    public func toStoredTunnel(tunnelID: UUID = UUID()) throws -> StoredTunnel {
        guard peers.count <= 1 else {
            throw TunnelRepositoryError.multiPeerNotSupported
        }
        let peer = peers.first

        return StoredTunnel(
            id: tunnelID,
            name: name ?? "",
            addresses: interface.addresses.map { $0.stringRepresentation },
            privateKey: interface.privateKey,
            listenPort: interface.listenPort.map { Int($0) },
            dns: interface.dns.map { $0.stringRepresentation } + interface.dnsSearch,
            mtu: interface.mtu.map { Int($0) },
            serverPublicKey: peer?.publicKey ?? Data(),
            serverEndpoint: peer?.endpoint?.stringRepresentation ?? "",
            allowedIPs: peer?.allowedIPs.map { $0.stringRepresentation } ?? [],
            presharedKey: peer?.preSharedKey,
            persistentKeepalive: peer?.persistentKeepAlive.map { Int($0) }
        )
    }

    /// Setzt eine `TunnelConfiguration` aus einem persistierten `StoredTunnel`
    /// wieder zusammen. Wird benutzt, wenn die NE den Tunnel starten will.
    public init(stored: StoredTunnel) {
        var interface = InterfaceConfiguration(privateKey: stored.privateKey)
        interface.addresses = stored.addresses.compactMap { IPAddressRange(from: $0) }
        interface.listenPort = stored.listenPort.map { UInt16(clamping: $0) }
        interface.mtu = stored.mtu.map { UInt16(clamping: $0) }
        // wg-quick mischt DNS-Server und Domain-Search-Pfade in einer Zeile;
        // wir trennen sie wieder beim Aufbau der Core-Struktur.
        var dnsServers = [DNSServer]()
        var dnsSearch = [String]()
        for token in stored.dns {
            if let server = DNSServer(from: token) {
                dnsServers.append(server)
            } else {
                dnsSearch.append(token)
            }
        }
        interface.dns = dnsServers
        interface.dnsSearch = dnsSearch

        var peers = [PeerConfiguration]()
        if !stored.serverPublicKey.isEmpty {
            var peer = PeerConfiguration(publicKey: stored.serverPublicKey)
            peer.endpoint = Endpoint(from: stored.serverEndpoint)
            peer.allowedIPs = stored.allowedIPs.compactMap { IPAddressRange(from: $0) }
            peer.preSharedKey = stored.presharedKey
            peer.persistentKeepAlive = stored.persistentKeepalive.map { UInt16(clamping: $0) }
            peers.append(peer)
        }

        self.init(
            name: stored.name.isEmpty ? nil : stored.name,
            interface: interface,
            peers: peers
        )
    }
}
