import Foundation

/// WireGuard-Schlüssel (Private, Public, Pre-Shared) sind Curve25519-Schlüssel,
/// d.h. exakt 32 Bytes Rohdaten. wg-quick-Configs codieren sie als Base64
/// (44 Zeichen inkl. `=`-Padding).
///
/// Wir speichern Schlüssel in Core als rohe `Data` (32 Bytes), nicht als
/// WireGuardKit-Typ (`PrivateKey`/`PublicKey`). Grund: Core darf nicht von
/// WireGuardKit abhängen — Companion-Editor (iOS-App) parst und editiert
/// Configs, ohne dass die Go-Bridge gelinkt sein darf.
///
/// Die Network Extension (tvOS) übersetzt Core-Keys → WireGuardKit-Keys
/// beim Start des Tunnels.
public enum WireGuardKey {

    /// Rohgröße eines Curve25519-Schlüssels in Bytes.
    public static let rawSize = 32

    /// Validiert einen Base64-String als 32-Byte-WireGuard-Schlüssel.
    /// Akzeptiert genau Schlüssel mit 32 Bytes Rohdaten; alle anderen
    /// Längen werden abgelehnt (auch wenn das Base64 dekodierbar wäre).
    ///
    /// - Returns: 32 Bytes `Data` bei Erfolg, `nil` bei ungültigem Input.
    public static func data(fromBase64 base64: String) -> Data? {
        guard let data = Data(base64Encoded: base64), data.count == rawSize else {
            return nil
        }
        return data
    }
}
