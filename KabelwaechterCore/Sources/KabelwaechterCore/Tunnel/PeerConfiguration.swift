// Adapted from WireGuardKit/Sources/WireGuardKit/PeerConfiguration.swift
// SPDX-License-Identifier: MIT
// Copyright © 2018-2023 WireGuard LLC. All Rights Reserved.

import Foundation

/// `[Peer]`-Sektion einer wg-quick-Config. Public Key und (optional) Pre-Shared
/// Key liegen als rohes 32-Byte-`Data` — siehe `WireGuardKey`.
public struct PeerConfiguration {
    public var publicKey: Data
    public var preSharedKey: Data?
    public var allowedIPs = [IPAddressRange]()
    public var endpoint: Endpoint?
    public var persistentKeepAlive: UInt16?

    public init(publicKey: Data) {
        self.publicKey = publicKey
    }
}

extension PeerConfiguration: Equatable {
    public static func == (lhs: PeerConfiguration, rhs: PeerConfiguration) -> Bool {
        return lhs.publicKey == rhs.publicKey
            && lhs.preSharedKey == rhs.preSharedKey
            && Set(lhs.allowedIPs) == Set(rhs.allowedIPs)
            && lhs.endpoint == rhs.endpoint
            && lhs.persistentKeepAlive == rhs.persistentKeepAlive
    }
}

extension PeerConfiguration: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(publicKey)
        hasher.combine(preSharedKey)
        hasher.combine(Set(allowedIPs))
        hasher.combine(endpoint)
        hasher.combine(persistentKeepAlive)
    }
}
