import Foundation
import KabelwaechterCore

/// Schmales DTO für die Tunnel-Liste — kombiniert nur die Felder, die für
/// die Listen-UI ausreichen. Der **vollständige** `TunnelConfiguration`
/// (Core-Typ, inkl. Private Key) wird nur via `tunnelConfiguration(id:)`
/// und nur dann geladen, wenn die NE-Übergabe ansteht.
public struct TunnelView: Equatable, Sendable {
    public let id: UUID
    public let name: String
    /// `true` wenn der Tunnel auf diesem Gerät startbar ist — d.h. ein
    /// Private Key liegt vor. Seit ADR-0003 synct der komplette Tunnel inkl.
    /// Key, also ist das normalerweise `true`, sobald der Tunnel überhaupt
    /// sichtbar ist. `false` nur in der kurzen Lücke, falls ein Record
    /// (theoretisch) ohne Key ankommt.
    public let isConfiguredHere: Bool
    public let serverEndpoint: String
    public let createdAt: Date

    public init(id: UUID, name: String, isConfiguredHere: Bool, serverEndpoint: String, createdAt: Date) {
        self.id = id
        self.name = name
        self.isConfiguredHere = isConfiguredHere
        self.serverEndpoint = serverEndpoint
        self.createdAt = createdAt
    }
}

/// Fehler, die `TunnelRepositoring`-Operationen produzieren können.
public enum TunnelRepositoryError: Error, Equatable {
    /// Kein Tunnel-Record zur gegebenen Tunnel-ID.
    case tunnelNotFound

    /// Tunnel existiert, hat aber (noch) keinen Private Key auf diesem Gerät.
    /// Praktisch nur in der kurzen Lücke, bevor der CloudKit-Record vollständig
    /// angekommen ist.
    case notConfiguredOnThisDevice

    /// Die wg-quick-Config enthält mehr als einen `[Peer]`-Block. Es werden
    /// nur Single-Peer-Tunnel unterstützt (typischer VPN-Client-Fall).
    case multiPeerNotSupported

    /// wg-quick-Parser hat einen Fehler geworfen — Wrapping für Aufrufer,
    /// die nicht beide Fehlerräume kennen müssen.
    case invalidWgQuickConfig(String)

    /// Ein Tunnel mit gleichem Server-PublicKey + gleicher Interface-Address
    /// existiert bereits (gleiche Peer-Identität). `existingName` ist sein
    /// Anzeige-Name für die Meldung.
    case duplicate(existingName: String)
}

/// Schnittstelle für CRUD auf Tunneln über einen `StoredTunnel`-Container.
@MainActor
public protocol TunnelRepositoring {

    /// Importiert eine wg-quick-Config als neuen `StoredTunnel` (inkl. Key).
    /// - Returns: die neue Tunnel-UUID.
    func importWgQuick(_ wgQuickConfig: String, named name: String) throws -> UUID

    /// Liefert alle Tunnel als schmale Liste.
    func allTunnels() throws -> [TunnelView]

    /// Liefert die View zu einer einzelnen Tunnel-ID.
    func tunnel(id: UUID) throws -> TunnelView

    /// Liefert die voll aufgelöste Core-`TunnelConfiguration` für die NE-
    /// Übergabe. Wirft `notConfiguredOnThisDevice`, wenn der Record noch
    /// keinen Private Key trägt.
    func tunnelConfiguration(id: UUID) throws -> TunnelConfiguration

    /// Löscht einen Tunnel komplett (auf allen iCloud-Geräten).
    /// Idempotent — ein nicht vorhandener Tunnel wird stillschweigend ignoriert.
    func deleteTunnel(id: UUID) throws
}
