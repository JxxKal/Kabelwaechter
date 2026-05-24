import Foundation
import Security

/// Produktive `KeychainStoring`-Implementierung über das Security-Framework.
///
/// Persistenz-Eigenschaften:
/// - **Access Level**: `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` —
///   Schlüssel sind nach dem ersten Entsperren seit Boot verfügbar (NE kann
///   nach Reboot auto-connecten) und werden **nie** iCloud-Keychain-synchronisiert
///   und **nie** in Backups übernommen.
/// - **Sharing**: optional via `accessGroup`-Parameter. Auf tvOS muss das die
///   App-Group der App + NE sein (`KabelwaechterConstants.keychainSharingGroup`),
///   sonst kann die NE den Key nicht lesen.
/// - **Namespace**: jedes Item wird mit `service` + `account` adressiert,
///   wobei `service` ein konstanter Bezeichner (z.B. `<bundlePrefix>.tunnels`)
///   und `account` die Tunnel-ID ist.
public struct KeychainStore: KeychainStoring {

    private let service: String
    private let accessGroup: String?

    /// - Parameters:
    ///   - service: Konstanter Service-Bezeichner für die Item-Klasse
    ///     (z.B. `"de.jankaluza.kabelwaechter.tunnels"`). Default leitet sich
    ///     vom Bundle-Prefix ab.
    ///   - accessGroup: Optionale Keychain-Access-Group für App-Group-Sharing.
    ///     `nil` heißt: nur in der Sandbox des aufrufenden Prozesses sichtbar.
    public init(
        service: String = KabelwaechterConstants.BundleIdentifiers.prefix + ".tunnels",
        accessGroup: String? = nil
    ) {
        self.service = service
        self.accessGroup = accessGroup
    }

    public func storePrivateKey(_ privateKey: Data, forTunnelID tunnelID: String) throws {
        guard privateKey.count == WireGuardKey.rawSize else {
            throw KeychainStoreError.invalidKeyLength
        }

        var query = baseQuery(forTunnelID: tunnelID)
        // Erst versuchen wir ein Update — wenn nichts da ist, fügen wir ein.
        let updateAttributes: [CFString: Any] = [
            kSecValueData: privateKey,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let updateStatus = SecItemUpdate(query as CFDictionary, updateAttributes as CFDictionary)

        switch updateStatus {
        case errSecSuccess:
            return
        case errSecItemNotFound:
            // Item existiert noch nicht — anlegen.
            query[kSecValueData] = privateKey
            query[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let addStatus = SecItemAdd(query as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainStoreError.osStatus(addStatus)
            }
        default:
            throw KeychainStoreError.osStatus(updateStatus)
        }
    }

    public func loadPrivateKey(forTunnelID tunnelID: String) throws -> Data {
        var query = baseQuery(forTunnelID: tunnelID)
        query[kSecReturnData] = true
        query[kSecMatchLimit] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            guard let data = result as? Data else {
                throw KeychainStoreError.notFound
            }
            return data
        case errSecItemNotFound:
            throw KeychainStoreError.notFound
        default:
            throw KeychainStoreError.osStatus(status)
        }
    }

    public func deletePrivateKey(forTunnelID tunnelID: String) throws {
        let query = baseQuery(forTunnelID: tunnelID)
        let status = SecItemDelete(query as CFDictionary)
        switch status {
        case errSecSuccess, errSecItemNotFound:
            return
        default:
            throw KeychainStoreError.osStatus(status)
        }
    }

    private func baseQuery(forTunnelID tunnelID: String) -> [CFString: Any] {
        var query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: tunnelID,
            kSecAttrSynchronizable: false
        ]
        if let accessGroup {
            query[kSecAttrAccessGroup] = accessGroup
        }
        return query
    }
}
