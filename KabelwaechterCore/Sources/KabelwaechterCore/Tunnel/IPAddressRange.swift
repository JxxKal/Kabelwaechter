// Adapted from WireGuardKit/Sources/WireGuardKit/IPAddressRange.swift
// SPDX-License-Identifier: MIT
// Copyright © 2018-2023 WireGuard LLC. All Rights Reserved.

import Foundation
import Network

/// CIDR-Adressbereich (Adresse + Netzwerk-Präfixlänge). Wird sowohl für
/// `Address` (Interface) als auch `AllowedIPs` (Peer) verwendet.
public struct IPAddressRange {
    public let address: IPAddress
    public let networkPrefixLength: UInt8

    public init(address: IPAddress, networkPrefixLength: UInt8) {
        self.address = address
        self.networkPrefixLength = networkPrefixLength
    }
}

extension IPAddressRange: Equatable {
    public static func == (lhs: IPAddressRange, rhs: IPAddressRange) -> Bool {
        return lhs.address.rawValue == rhs.address.rawValue
            && lhs.networkPrefixLength == rhs.networkPrefixLength
    }
}

extension IPAddressRange: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(address.rawValue)
        hasher.combine(networkPrefixLength)
    }
}

extension IPAddressRange {

    public var stringRepresentation: String {
        return "\(address)/\(networkPrefixLength)"
    }

    public init?(from string: String) {
        let endOfIPAddress = string.lastIndex(of: "/") ?? string.endIndex
        let addressString = String(string[string.startIndex ..< endOfIPAddress])
        let address: IPAddress
        if let addr = IPv4Address(addressString) {
            address = addr
        } else if let addr = IPv6Address(addressString) {
            address = addr
        } else {
            return nil
        }

        let maxNetworkPrefixLength: UInt8 = address is IPv4Address ? 32 : 128
        let networkPrefixLength: UInt8
        if endOfIPAddress < string.endIndex {
            let indexOfNetworkPrefixLength = string.index(after: endOfIPAddress)
            guard indexOfNetworkPrefixLength < string.endIndex else { return nil }
            let npLSub = string[indexOfNetworkPrefixLength ..< string.endIndex]
            guard let npl = UInt8(npLSub) else { return nil }
            networkPrefixLength = min(npl, maxNetworkPrefixLength)
        } else {
            networkPrefixLength = maxNetworkPrefixLength
        }

        self.address = address
        self.networkPrefixLength = networkPrefixLength
    }
}
