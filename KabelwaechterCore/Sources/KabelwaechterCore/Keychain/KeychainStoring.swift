import Foundation

/// Schnittstelle zum Speichern und Lesen von Per-Device-WireGuard-Private-Keys.
///
/// **Per-Device-Geheimnis-Design** (Plan §14 / Phase 2.2): Der Private Key
/// eines Tunnels wird nie zwischen Geräten synchronisiert. Jedes Gerät
/// generiert (oder importiert) seinen eigenen Schlüssel und veröffentlicht
/// nur den abgeleiteten Public Key für die Peer-Konfiguration. Tunnel-
/// Metadaten (Peer-PublicKey, Endpoint, AllowedIPs …) liegen separat im
/// SwiftData/CloudKit-Modell.
///
/// Implementierungen:
/// - `KeychainStore` — produktiv, Security-Framework, App-Group-shared zwischen
///   tvOS-App und tvOS-NE, `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`.
/// - `InMemoryKeychainStore` — Test/Preview-Fake.
public protocol KeychainStoring {

    /// Speichert (oder überschreibt) den Private Key für die gegebene Tunnel-ID.
    /// - Parameter privateKey: Curve25519-Schlüssel als rohe `Data` (genau 32 Bytes).
    /// - Throws: `KeychainStoreError.invalidKeyLength` bei falscher Länge,
    ///   `.osStatus` bei einem Security-Framework-Fehler.
    func storePrivateKey(_ privateKey: Data, forTunnelID tunnelID: String) throws

    /// Lädt den Private Key zur gegebenen Tunnel-ID.
    /// - Throws: `KeychainStoreError.notFound` wenn kein Eintrag existiert,
    ///   `.osStatus` bei einem Security-Framework-Fehler.
    func loadPrivateKey(forTunnelID tunnelID: String) throws -> Data

    /// Löscht den Private Key zur gegebenen Tunnel-ID. No-Op wenn kein Eintrag
    /// existiert (idempotent).
    /// - Throws: `.osStatus` bei einem Security-Framework-Fehler.
    func deletePrivateKey(forTunnelID tunnelID: String) throws
}

/// Fehler, die ein `KeychainStoring`-Aufruf produzieren kann.
public enum KeychainStoreError: Error, Equatable {
    /// Kein Eintrag für die gegebene Tunnel-ID gefunden.
    case notFound

    /// Übergebener Schlüssel hat nicht die erwartete Curve25519-Länge
    /// (`WireGuardKey.rawSize` = 32 Bytes).
    case invalidKeyLength

    /// Security-Framework hat einen Fehlerstatus zurückgegeben, der weder
    /// "nicht gefunden" noch "Erfolg" ist. Roher OSStatus zur Diagnose.
    case osStatus(OSStatus)
}
