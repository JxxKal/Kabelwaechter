import Foundation

/// In-Memory-Implementierung von `KeychainStoring`. Hält Schlüssel in einem
/// Dictionary, keine Persistenz. Verwendet von Tests und SwiftUI-Previews.
///
/// Thread-Safety: synchronisiert via internes `NSLock`. Erfüllt damit das
/// `Sendable`-Versprechen (final class + interner Lock).
public final class InMemoryKeychainStore: KeychainStoring, @unchecked Sendable {

    private let lock = NSLock()
    private var keys: [String: Data] = [:]

    public init() {}

    public func storePrivateKey(_ privateKey: Data, forTunnelID tunnelID: String) throws {
        guard privateKey.count == WireGuardKey.rawSize else {
            throw KeychainStoreError.invalidKeyLength
        }
        lock.lock(); defer { lock.unlock() }
        keys[tunnelID] = privateKey
    }

    public func loadPrivateKey(forTunnelID tunnelID: String) throws -> Data {
        lock.lock(); defer { lock.unlock() }
        guard let key = keys[tunnelID] else {
            throw KeychainStoreError.notFound
        }
        return key
    }

    public func deletePrivateKey(forTunnelID tunnelID: String) throws {
        lock.lock(); defer { lock.unlock() }
        keys.removeValue(forKey: tunnelID)
    }
}
