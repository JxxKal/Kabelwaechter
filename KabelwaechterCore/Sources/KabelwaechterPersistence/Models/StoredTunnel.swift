import Foundation
import SwiftData

/// Ein vollständiger Tunnel, wie er persistiert und via CloudKit
/// (Private-Datenbank) zwischen allen Geräten desselben Apple-Accounts
/// synchronisiert wird — **inklusive** Interface-Adresse und Private Key.
///
/// Frühere Versionen splitteten den Tunnel in einen gerätegeteilten
/// `TunnelTemplate` (CloudKit) und einen gerätelokalen `TunnelInstance`
/// (lokal), um Per-Device-Geheimnisse aus iCloud rauszuhalten (Decision #9 /
/// ADR-0001). Diese Trennung wurde **revidiert**: eine importierte wg-quick-
/// Config soll als Ganzes auf alle Geräte syncen, damit am Apple TV nichts
/// nachgetippt werden muss (siehe ADR-0003). Ein zweites Apple TV mit eigener
/// Identität richtet man weiterhin über den manuellen `+`-Import ein.
///
/// CloudKit-Einschränkungen, denen das Schema folgt: alle Attribute haben
/// Defaults (`@Model`-Required-without-Default ist mit CloudKit unzulässig);
/// keine `@Attribute(.unique)`-Constraints; keine Required-Relationships.
/// Zielgerät eines Tunnels — bestimmt, wo er verbindet und wie er in der
/// iOS-Liste gruppiert wird. `appleTV` (Default, auch für Bestandsdaten):
/// die Apple TV baut ihn auf, das iPhone zeigt ihn separiert/nicht-verbindbar.
/// `phone`: das iPhone baut ihn auf. Umschaltbar per „Verschieben".
public enum TunnelTarget: String, Codable, Sendable, CaseIterable {
    case phone
    case appleTV
}

@Model
public final class StoredTunnel {
    /// Tunnel-Identität — stabil über alle Geräte (kommt mit dem CloudKit-
    /// Record mit). Eindeutigkeit wird applikativ garantiert (im
    /// `TunnelRepository`); CloudKit unterstützt keine `unique`-Constraints.
    public var id: UUID = UUID()

    /// Display-Name in der Tunnel-Liste — von User editierbar.
    public var name: String = ""

    // MARK: Interface (eigenes Gerät)

    /// Interface-Adressen aus der `[Interface]`-Sektion, z.B.
    /// `["10.0.0.5/32", "fd00::5/128"]`.
    public var addresses: [String] = []

    /// Curve25519-Private-Key dieses Tunnels (32 Bytes, roh). Wird mit-synced.
    /// At-rest geschützt durch SwiftData/CloudKit; E2E nur mit aktivierter
    /// Advanced Data Protection (bewusster Trade-off, siehe ADR-0003).
    public var privateKey: Data = Data()

    /// Lokaler ListenPort — meist `nil` bei Client-Tunneln. `Int?` weil
    /// SwiftData `UInt16` nicht direkt mag.
    public var listenPort: Int?

    /// DNS-Server + Domain-Search-Pfade gemischt (wg-quick-Konvention).
    /// Trennung in Server vs. Search-Paths passiert beim Parsen.
    public var dns: [String] = []

    /// MTU-Override aus der `[Interface]`-Sektion; oft nicht gesetzt.
    /// `Int?` weil SwiftData `UInt16` nicht direkt mag.
    public var mtu: Int?

    // MARK: Peer (Server)

    /// Curve25519-Public-Key des Servers (32 Bytes). Aus der `[Peer]`-Sektion.
    public var serverPublicKey: Data = Data()

    /// Server-Adresse + Port als wg-quick-String, z.B. `"vpn.example.com:51820"`
    /// oder `"[2001:db8::1]:51820"`. Wird via `Endpoint(from:)` (Core) geparst.
    public var serverEndpoint: String = ""

    /// Routing-Policy: welche IPs durch den Tunnel gehen. wg-quick-Strings,
    /// z.B. `["0.0.0.0/0", "::/0"]` für Full-Tunnel.
    public var allowedIPs: [String] = []

    /// Optionaler symmetrischer Zusatzschlüssel (32 Bytes).
    public var presharedKey: Data?

    /// NAT-Traversal-Setting in Sekunden. `Int?` aus demselben Grund wie `mtu`.
    public var persistentKeepalive: Int?

    /// Erstellungszeitpunkt, hilfreich für Sortierung und Debugging.
    public var createdAt: Date = Date()

    /// Zielgerät (Rolle) als Roh-String für CloudKit-Kompatibilität. Default
    /// `appleTV` — so bleiben bereits gesyncte Bestandsdaten Apple-TV-Tunnel.
    public var targetRaw: String = TunnelTarget.appleTV.rawValue

    /// Typisierter Zugriff auf `targetRaw`.
    public var target: TunnelTarget {
        get { TunnelTarget(rawValue: targetRaw) ?? .appleTV }
        set { targetRaw = newValue.rawValue }
    }

    public init(
        id: UUID = UUID(),
        name: String = "",
        addresses: [String] = [],
        privateKey: Data = Data(),
        listenPort: Int? = nil,
        dns: [String] = [],
        mtu: Int? = nil,
        serverPublicKey: Data = Data(),
        serverEndpoint: String = "",
        allowedIPs: [String] = [],
        presharedKey: Data? = nil,
        persistentKeepalive: Int? = nil,
        createdAt: Date = Date(),
        target: TunnelTarget = .appleTV
    ) {
        self.id = id
        self.name = name
        self.addresses = addresses
        self.privateKey = privateKey
        self.listenPort = listenPort
        self.dns = dns
        self.mtu = mtu
        self.serverPublicKey = serverPublicKey
        self.serverEndpoint = serverEndpoint
        self.allowedIPs = allowedIPs
        self.presharedKey = presharedKey
        self.persistentKeepalive = persistentKeepalive
        self.createdAt = createdAt
        self.targetRaw = target.rawValue
    }
}
