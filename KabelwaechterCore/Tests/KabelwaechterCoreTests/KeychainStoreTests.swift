import Testing
import Foundation
@testable import KabelwaechterCore

/// Tests gegen das `KeychainStoring`-Protocol. Laufen mit dem
/// `InMemoryKeychainStore`-Fake — der echte `KeychainStore` (Security-
/// Framework) braucht eine signierte App mit App-Group-Entitlement und
/// wird nicht im swift-test-Kontext getestet.
@Suite("KeychainStore (protocol contract)")
struct KeychainStoreTests {

    static let key32 = Data(repeating: 0xAB, count: 32)
    static let otherKey32 = Data(repeating: 0xCD, count: 32)
    static let tunnelA = "tunnel-A-uuid"
    static let tunnelB = "tunnel-B-uuid"

    @Test("store → load gibt denselben Key zurück")
    func storeAndLoad() throws {
        let store = InMemoryKeychainStore()
        try store.storePrivateKey(Self.key32, forTunnelID: Self.tunnelA)
        let loaded = try store.loadPrivateKey(forTunnelID: Self.tunnelA)
        #expect(loaded == Self.key32)
    }

    @Test("load auf unbekannte TunnelID wirft notFound")
    func loadMissing() {
        let store = InMemoryKeychainStore()
        #expect(throws: KeychainStoreError.notFound) {
            _ = try store.loadPrivateKey(forTunnelID: "does-not-exist")
        }
    }

    @Test("store überschreibt vorhandenen Key (idempotent)")
    func overwrite() throws {
        let store = InMemoryKeychainStore()
        try store.storePrivateKey(Self.key32, forTunnelID: Self.tunnelA)
        try store.storePrivateKey(Self.otherKey32, forTunnelID: Self.tunnelA)
        let loaded = try store.loadPrivateKey(forTunnelID: Self.tunnelA)
        #expect(loaded == Self.otherKey32)
    }

    @Test("delete entfernt nur den genannten Eintrag")
    func deleteIsolated() throws {
        let store = InMemoryKeychainStore()
        try store.storePrivateKey(Self.key32, forTunnelID: Self.tunnelA)
        try store.storePrivateKey(Self.otherKey32, forTunnelID: Self.tunnelB)
        try store.deletePrivateKey(forTunnelID: Self.tunnelA)

        #expect(throws: KeychainStoreError.notFound) {
            _ = try store.loadPrivateKey(forTunnelID: Self.tunnelA)
        }
        let bStill = try store.loadPrivateKey(forTunnelID: Self.tunnelB)
        #expect(bStill == Self.otherKey32)
    }

    @Test("delete auf unbekannte TunnelID ist No-Op (kein Fehler)")
    func deleteUnknownIsNoOp() {
        let store = InMemoryKeychainStore()
        #expect(throws: Never.self) {
            try store.deletePrivateKey(forTunnelID: "never-stored")
        }
    }

    @Test("Falsche Key-Länge (≠32 Bytes) wirft invalidKeyLength")
    func rejectsWrongLength() {
        let store = InMemoryKeychainStore()
        let shortKey = Data(repeating: 0x01, count: 16)
        #expect(throws: KeychainStoreError.invalidKeyLength) {
            try store.storePrivateKey(shortKey, forTunnelID: Self.tunnelA)
        }
    }
}
