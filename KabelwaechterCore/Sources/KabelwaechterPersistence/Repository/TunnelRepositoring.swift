import Foundation
import KabelwaechterCore

/// Schmales DTO für die Tunnel-Liste — kombiniert nur die Felder, die für
/// die Listen-UI ausreichen. Der **vollständige** `TunnelConfiguration`
/// (Core-Typ, inkl. Private Key) wird nur via `tunnelConfiguration(id:)`
/// und nur dann geladen, wenn die NE-Übergabe ansteht.
public struct TunnelView: Equatable, Sendable {
    public let id: UUID
    public let name: String
    /// `true` wenn auf diesem Gerät ein `TunnelInstance` UND ein Private Key
    /// im Keychain vorliegen — d.h. der Tunnel kann hier gestartet werden.
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
    /// Kein Template/Instance/Keychain-Eintrag zur gegebenen Tunnel-ID.
    case tunnelNotFound

    /// Tunnel existiert als Template (via CloudKit gesehen), wurde aber noch
    /// nicht auf diesem Gerät eingerichtet — kein lokaler `TunnelInstance`.
    case notConfiguredOnThisDevice

    /// Die wg-quick-Config enthält mehr als einen `[Peer]`-Block. Phase 2.3
    /// unterstützt nur Single-Peer-Tunnel (typischer VPN-Client-Fall).
    case multiPeerNotSupported

    /// wg-quick-Parser hat einen Fehler geworfen — Wrapping für Aufrufer,
    /// die nicht beide Fehlerräume kennen müssen.
    case invalidWgQuickConfig(String)
}

/// Schnittstelle für CRUD auf Tunneln. Kombiniert `TunnelTemplate`-Container,
/// `TunnelInstance`-Container und `KeychainStoring` zu einer Sicht.
@MainActor
public protocol TunnelRepositoring {

    /// Importiert eine wg-quick-Config: splittet in `TunnelTemplate` +
    /// `TunnelInstance`, schreibt den Private Key in den Keychain.
    /// - Returns: die neue Tunnel-UUID.
    func importWgQuick(_ wgQuickConfig: String, named name: String) throws -> UUID

    /// Liefert alle Tunnel als schmale Liste (gemerged über beide Container).
    func allTunnels() throws -> [TunnelView]

    /// Liefert die View zu einer einzelnen Tunnel-ID.
    func tunnel(id: UUID) throws -> TunnelView

    /// Liefert die voll aufgelöste Core-`TunnelConfiguration` für die NE-
    /// Übergabe. Wirft `notConfiguredOnThisDevice` wenn auf diesem Gerät
    /// kein `TunnelInstance` oder kein Keychain-Eintrag existiert.
    func tunnelConfiguration(id: UUID) throws -> TunnelConfiguration

    /// Löscht einen Tunnel komplett: Template, Instance, Keychain.
    /// Idempotent — fehlende Teile werden stillschweigend übersprungen.
    func deleteTunnel(id: UUID) throws

    /// Richtet einen via CloudKit empfangenen Tunnel auf diesem Gerät ein.
    /// Erwartet eine wg-quick-Config — die `[Interface]`-Daten daraus
    /// landen im neuen `TunnelInstance` + Keychain; die `[Peer]`-Daten
    /// müssen mit dem existierenden `TunnelTemplate` übereinstimmen
    /// (Validation deferred — Phase 2.4).
    func attachInstance(toTunnelID id: UUID, wgQuickConfig: String) throws
}
