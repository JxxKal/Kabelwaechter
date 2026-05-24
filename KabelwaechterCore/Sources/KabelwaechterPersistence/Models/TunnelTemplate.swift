import Foundation
import SwiftData

/// Geräte-geteilter Teil eines Tunnels — alles, was identisch sein muss,
/// damit zwei Geräte denselben Server kontaktieren. Wird via CloudKit
/// (private-Datenbank) zwischen Geräten desselben Apple-Accounts
/// synchronisiert.
///
/// Siehe `CONTEXT.md` für die Domain-Sprache und `docs/adr/0001` für die
/// Begründung der TunnelTemplate/TunnelInstance-Trennung.
///
/// CloudKit-Einschränkungen, denen das Schema folgt: alle Attribute haben
/// Defaults (`@Model`-Required-without-Default ist mit CloudKit unzulässig);
/// keine `@Attribute(.unique)`-Constraints; keine Required-Relationships.
@Model
public final class TunnelTemplate {
    /// Gemeinsame Tunnel-Identität — verbindet diesen Template mit dem
    /// gerätelokalen `TunnelInstance` und dem Keychain-Eintrag. Eindeutigkeit
    /// wird applikativ garantiert (im `TunnelRepository`); CloudKit unterstützt
    /// keine `unique`-Constraints.
    public var id: UUID = UUID()

    /// Display-Name in der Tunnel-Liste — von User editierbar.
    public var name: String = ""

    /// Curve25519-Public-Key des Servers (32 Bytes). Aus der `[Peer]`-Sektion.
    public var serverPublicKey: Data = Data()

    /// Server-Adresse + Port als wg-quick-String, z.B. `"vpn.example.com:51820"`
    /// oder `"[2001:db8::1]:51820"`. Wird via `Endpoint(from:)` (Core) geparst.
    public var serverEndpoint: String = ""

    /// Routing-Policy: welche IPs durch den Tunnel gehen. wg-quick-Strings,
    /// z.B. `["0.0.0.0/0", "::/0"]` für Full-Tunnel.
    public var allowedIPs: [String] = []

    /// DNS-Server + Domain-Search-Pfade gemischt (wg-quick-Konvention).
    /// Trennung in Server vs. Search-Paths passiert beim Parsen.
    public var dns: [String] = []

    /// MTU-Override aus der `[Interface]`-Sektion; oft nicht gesetzt.
    /// `Int?` weil SwiftData `UInt16` nicht direkt mag.
    public var mtu: Int?

    /// Optionaler symmetrischer Zusatzschlüssel (32 Bytes). Wird mit-synced —
    /// ohne Sync funktioniert PSK über Geräte hinweg nicht (siehe CONTEXT.md).
    public var presharedKey: Data?

    /// NAT-Traversal-Setting in Sekunden. `Int?` aus demselben Grund wie `mtu`.
    public var persistentKeepalive: Int?

    /// Erstellungszeitpunkt, hilfreich für Sortierung und Debugging.
    public var createdAt: Date = Date()

    public init(
        id: UUID = UUID(),
        name: String = "",
        serverPublicKey: Data = Data(),
        serverEndpoint: String = "",
        allowedIPs: [String] = [],
        dns: [String] = [],
        mtu: Int? = nil,
        presharedKey: Data? = nil,
        persistentKeepalive: Int? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.serverPublicKey = serverPublicKey
        self.serverEndpoint = serverEndpoint
        self.allowedIPs = allowedIPs
        self.dns = dns
        self.mtu = mtu
        self.presharedKey = presharedKey
        self.persistentKeepalive = persistentKeepalive
        self.createdAt = createdAt
    }
}
