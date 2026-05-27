import Foundation
import KabelwaechterCore
import WireGuardKit

/// Mapping zwischen `KabelwaechterCore.TunnelConfiguration` und der
/// WireGuardKit-Repräsentation, die der `WireGuardAdapter` erwartet.
/// Core hat eigene Modelltypen (Keys als rohe `Data`); nur die NE linkt
/// WireGuardKit und übersetzt beim Start.
enum CoreToWireGuardKit {

    enum MappingError: Error {
        case invalidPrivateKey
        case invalidPublicKey
        case invalidPreSharedKey
        case invalidAddressString(String)
    }

    static func adapt(_ core: KabelwaechterCore.TunnelConfiguration) throws -> WireGuardKit.TunnelConfiguration {
        guard let privateKey = WireGuardKit.PrivateKey(rawValue: core.interface.privateKey) else {
            throw MappingError.invalidPrivateKey
        }
        var iface = WireGuardKit.InterfaceConfiguration(privateKey: privateKey)
        iface.addresses = try core.interface.addresses.map { coreRange in
            guard let wgRange = WireGuardKit.IPAddressRange(from: coreRange.stringRepresentation) else {
                throw MappingError.invalidAddressString(coreRange.stringRepresentation)
            }
            return wgRange
        }
        iface.listenPort = core.interface.listenPort
        iface.mtu = core.interface.mtu
        iface.dns = core.interface.dns.map { WireGuardKit.DNSServer(address: $0.address) }
        iface.dnsSearch = core.interface.dnsSearch

        let peers: [WireGuardKit.PeerConfiguration] = try core.peers.map { corePeer in
            guard let pubKey = WireGuardKit.PublicKey(rawValue: corePeer.publicKey) else {
                throw MappingError.invalidPublicKey
            }
            var peer = WireGuardKit.PeerConfiguration(publicKey: pubKey)
            if let psk = corePeer.preSharedKey {
                guard let wgPSK = WireGuardKit.PreSharedKey(rawValue: psk) else {
                    throw MappingError.invalidPreSharedKey
                }
                peer.preSharedKey = wgPSK
            }
            peer.allowedIPs = try corePeer.allowedIPs.map { coreRange in
                guard let wgRange = WireGuardKit.IPAddressRange(from: coreRange.stringRepresentation) else {
                    throw MappingError.invalidAddressString(coreRange.stringRepresentation)
                }
                return wgRange
            }
            if let coreEndpoint = corePeer.endpoint {
                peer.endpoint = WireGuardKit.Endpoint(host: coreEndpoint.host, port: coreEndpoint.port)
            }
            peer.persistentKeepAlive = corePeer.persistentKeepAlive
            return peer
        }

        return WireGuardKit.TunnelConfiguration(name: core.name, interface: iface, peers: peers)
    }
}
