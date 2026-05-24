// Adapted from WireGuardKit/Sources/WireGuardKit/TunnelConfiguration.swift
// SPDX-License-Identifier: MIT
// Copyright © 2018-2023 WireGuard LLC. All Rights Reserved.

import Foundation

/// In-Memory-Repräsentation eines WireGuard-Tunnels (parsed wg-quick-Config).
///
/// Bewusst als `struct` mit Wert-Semantik gehalten — passt zu späteren
/// SwiftData-`@Model`-Wrappern und CloudKit-Records, und vereinfacht
/// Concurrency.
///
/// Identität eines Tunnels (Apple-Vorschrift, NEVPNManager): die Peers müssen
/// paarweise verschiedene Public Keys haben. Wird in `init(fromWgQuickConfig:)`
/// erzwungen und in `init` als Precondition validiert.
public struct TunnelConfiguration {
    public var name: String?
    public var interface: InterfaceConfiguration
    public var peers: [PeerConfiguration]

    public init(name: String?, interface: InterfaceConfiguration, peers: [PeerConfiguration]) {
        let publicKeys = peers.map { $0.publicKey }
        precondition(Set(publicKeys).count == publicKeys.count,
                     "Two or more peers cannot have the same public key")
        self.name = name
        self.interface = interface
        self.peers = peers
    }
}

extension TunnelConfiguration: Equatable {
    public static func == (lhs: TunnelConfiguration, rhs: TunnelConfiguration) -> Bool {
        return lhs.name == rhs.name
            && lhs.interface == rhs.interface
            && Set(lhs.peers) == Set(rhs.peers)
    }
}
