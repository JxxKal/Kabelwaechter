// Adapted from WireGuardKit/Sources/WireGuardKit/InterfaceConfiguration.swift
// SPDX-License-Identifier: MIT
// Copyright © 2018-2023 WireGuard LLC. All Rights Reserved.

import Foundation
import Network

/// `[Interface]`-Sektion einer wg-quick-Config. Der Private Key liegt hier als
/// rohes 32-Byte-`Data` — siehe `WireGuardKey` für die Begründung.
///
/// Achtung: In Produktion wird der Private Key **nicht** mit dem Tunnel-
/// Modell zusammen in CloudKit synchronisiert. Er wird Per-Device im Keychain
/// gehalten (siehe Plan §14 / KeychainStore-Slice). Das Feld ist hier nur
/// für den lokalen In-Memory-Aufenthalt während Parse/Edit.
public struct InterfaceConfiguration {
    public var privateKey: Data
    public var addresses = [IPAddressRange]()
    public var listenPort: UInt16?
    public var mtu: UInt16?
    public var dns = [DNSServer]()
    public var dnsSearch = [String]()

    public init(privateKey: Data) {
        self.privateKey = privateKey
    }
}

extension InterfaceConfiguration: Equatable {
    public static func == (lhs: InterfaceConfiguration, rhs: InterfaceConfiguration) -> Bool {
        let lhsAddresses = lhs.addresses.filter { $0.address is IPv4Address }
            + lhs.addresses.filter { $0.address is IPv6Address }
        let rhsAddresses = rhs.addresses.filter { $0.address is IPv4Address }
            + rhs.addresses.filter { $0.address is IPv6Address }

        return lhs.privateKey == rhs.privateKey
            && lhsAddresses == rhsAddresses
            && lhs.listenPort == rhs.listenPort
            && lhs.mtu == rhs.mtu
            && lhs.dns == rhs.dns
            && lhs.dnsSearch == rhs.dnsSearch
    }
}
