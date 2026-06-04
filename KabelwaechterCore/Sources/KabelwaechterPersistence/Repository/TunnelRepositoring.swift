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
    /// Zielgerät — steuert Gruppierung (iOS) und ob die TV ihn verbindet.
    /// (Altes {phone,appleTV}-Modell; bleibt für Migration/Bestand bestehen.)
    public let target: TunnelTarget

    /// Besitzer-Gerät (Phase 7 / Milestone C). `nil` = frei/nicht zugewiesen.
    public let ownerDeviceID: String?
    /// Anzeigename des Besitzer-Geräts (für die Section-Überschrift auf anderen
    /// Geräten).
    public let ownerDeviceName: String?

    public init(id: UUID, name: String, isConfiguredHere: Bool, serverEndpoint: String, createdAt: Date, target: TunnelTarget, ownerDeviceID: String? = nil, ownerDeviceName: String? = nil) {
        self.id = id
        self.name = name
        self.isConfiguredHere = isConfiguredHere
        self.serverEndpoint = serverEndpoint
        self.createdAt = createdAt
        self.target = target
        self.ownerDeviceID = ownerDeviceID
        self.ownerDeviceName = ownerDeviceName
    }

    /// `true`, wenn der Tunnel keinem Gerät zugewiesen ist (frei).
    public var isFree: Bool { ownerDeviceID == nil }

    /// `true`, wenn der Tunnel dem Gerät mit `deviceID` gehört (→ „Meine Tunnel",
    /// verbindbar).
    public func isOwned(by deviceID: String) -> Bool { ownerDeviceID == deviceID }
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
    /// - Parameter target: Zielgerät (iOS-Import → `.phone`, tvOS → `.appleTV`).
    /// - Returns: die neue Tunnel-UUID.
    func importWgQuick(_ wgQuickConfig: String, named name: String, target: TunnelTarget) throws -> UUID

    /// Setzt das Zielgerät eines Tunnels („Auf Apple TV verschieben" / zurück).
    func setTarget(_ target: TunnelTarget, forTunnelID id: UUID) throws

    /// Weist einen Tunnel einem Gerät zu („Auf diesem Gerät verwenden"). Der
    /// `ownerDeviceName` wird denormalisiert mitgespeichert (Section-Überschrift
    /// auf anderen Geräten). Erst nach Zuweisung an das eigene Gerät dürfen
    /// Verbinden/Auto-Connect aktiviert werden.
    func assign(tunnelID id: UUID, toDeviceID deviceID: String, named deviceName: String) throws

    /// Gibt einen Tunnel frei (Besitzer entfernen) → erscheint wieder als „frei"
    /// und kann von einem anderen Gerät beansprucht werden.
    func freeTunnel(id: UUID) throws

    /// Aktualisiert einen bestehenden Tunnel (gleiche ID, damit CloudKit es als
    /// Änderung synct statt als neuen Record): überschreibt Name + alle Felder
    /// aus der neuen wg-quick-Config. Wirft `tunnelNotFound`, wenn die ID fehlt.
    func updateTunnel(id: UUID, name: String, wgQuickConfig: String) throws

    /// Liefert alle Tunnel als schmale Liste.
    func allTunnels() throws -> [TunnelView]

    /// Liefert die View zu einer einzelnen Tunnel-ID.
    func tunnel(id: UUID) throws -> TunnelView

    /// Liefert die voll aufgelöste Core-`TunnelConfiguration` für die NE-
    /// Übergabe. Wirft `notConfiguredOnThisDevice`, wenn der Record noch
    /// keinen Private Key trägt.
    func tunnelConfiguration(id: UUID) throws -> TunnelConfiguration

    /// Anzeige-Variante der Tunnel-Konfiguration für die Detail-View. Default
    /// gibt die echte Config zurück. Implementierungen können maskierte
    /// Werte liefern (z.B. `ScreenshotData` → synthetische Demo-Config für
    /// App-Preview-Aufnahmen).
    func displayConfiguration(id: UUID) throws -> TunnelConfiguration

    /// Löscht einen Tunnel komplett (auf allen iCloud-Geräten).
    /// Idempotent — ein nicht vorhandener Tunnel wird stillschweigend ignoriert.
    func deleteTunnel(id: UUID) throws
}

public extension TunnelRepositoring {
    /// Bequemlichkeit: Import mit Default-Ziel `.appleTV` (Bestands-Verhalten).
    func importWgQuick(_ wgQuickConfig: String, named name: String) throws -> UUID {
        try importWgQuick(wgQuickConfig, named: name, target: .appleTV)
    }

    /// Default: Anzeige-Variante == echte Config. Wird in
    /// `InMemoryTunnelRepository` überschrieben, sobald ein
    /// Display-Endpoint-Override existiert (Screenshot-/Preview-Modus).
    func displayConfiguration(id: UUID) throws -> TunnelConfiguration {
        try tunnelConfiguration(id: id)
    }
}
