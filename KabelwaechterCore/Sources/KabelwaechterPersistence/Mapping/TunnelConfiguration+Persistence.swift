import Foundation
import KabelwaechterCore

/// Brücke zwischen der Core-Domäne (`TunnelConfiguration`) und der
/// Persistenz-Repräsentation (`TunnelTemplate` + `TunnelInstance` + Private Key).
///
/// Phase-2.3-Scope: nur Single-Peer-Tunnel (typischer VPN-Client-Fall).
/// Multi-Peer wird abgewiesen — siehe `TunnelRepositoryError.multiPeerNotSupported`.
extension TunnelConfiguration {

    /// Splittet eine Core-`TunnelConfiguration` für die Persistenz.
    /// - Returns: Tupel aus neuem Template, neuem Instance und dem Private Key,
    ///   bereit für Keychain-Eintrag.
    /// - Throws: `TunnelRepositoryError.multiPeerNotSupported` bei mehr als
    ///   einem Peer.
    public func splitForPersistence(tunnelID: UUID = UUID()) throws -> (TunnelTemplate, TunnelInstance, Data) {
        guard peers.count <= 1 else {
            throw TunnelRepositoryError.multiPeerNotSupported
        }
        let peer = peers.first

        let template = TunnelTemplate(
            id: tunnelID,
            name: name ?? "",
            serverPublicKey: peer?.publicKey ?? Data(),
            serverEndpoint: peer?.endpoint?.stringRepresentation ?? "",
            allowedIPs: peer?.allowedIPs.map { $0.stringRepresentation } ?? [],
            dns: interface.dns.map { $0.stringRepresentation } + interface.dnsSearch,
            mtu: interface.mtu.map { Int($0) },
            presharedKey: peer?.preSharedKey,
            persistentKeepalive: peer?.persistentKeepAlive.map { Int($0) }
        )

        let instance = TunnelInstance(
            templateID: tunnelID,
            addresses: interface.addresses.map { $0.stringRepresentation },
            listenPort: interface.listenPort.map { Int($0) }
        )

        return (template, instance, interface.privateKey)
    }

    /// Setzt eine `TunnelConfiguration` aus den Persistenz-Teilen wieder zusammen.
    /// Wird benutzt, wenn die NE den Tunnel starten will.
    public init(template: TunnelTemplate, instance: TunnelInstance, privateKey: Data) {
        var interface = InterfaceConfiguration(privateKey: privateKey)
        interface.addresses = instance.addresses.compactMap { IPAddressRange(from: $0) }
        interface.listenPort = instance.listenPort.map { UInt16(clamping: $0) }
        interface.mtu = (instance.mtuOverride ?? template.mtu).map { UInt16(clamping: $0) }
        // wg-quick mischt DNS-Server und Domain-Search-Pfade in einer Zeile;
        // wir trennen sie wieder beim Aufbau der Core-Struktur.
        var dnsServers = [DNSServer]()
        var dnsSearch = [String]()
        for token in template.dns {
            if let server = DNSServer(from: token) {
                dnsServers.append(server)
            } else {
                dnsSearch.append(token)
            }
        }
        interface.dns = dnsServers
        interface.dnsSearch = dnsSearch

        var peers = [PeerConfiguration]()
        if !template.serverPublicKey.isEmpty {
            var peer = PeerConfiguration(publicKey: template.serverPublicKey)
            peer.endpoint = Endpoint(from: template.serverEndpoint)
            peer.allowedIPs = template.allowedIPs.compactMap { IPAddressRange(from: $0) }
            peer.preSharedKey = template.presharedKey
            peer.persistentKeepAlive = template.persistentKeepalive.map { UInt16(clamping: $0) }
            peers.append(peer)
        }

        self.init(
            name: template.name.isEmpty ? nil : template.name,
            interface: interface,
            peers: peers
        )
    }
}
