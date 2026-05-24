import Foundation
import SwiftData

/// Gerätelokaler Teil eines Tunnels — die Felder, die jedes Gerät individuell
/// hält und die **niemals** synchronisiert werden dürfen. Lebt in einem
/// ModelContainer mit `cloudKitDatabase: .none`.
///
/// Der `PrivateKey` selbst liegt nicht hier, sondern im Keychain
/// (siehe Phase 2.2 / `KabelwaechterCore.KeychainStore`) — `TunnelInstance`
/// referenziert ihn implizit über `templateID` (= UUID, die auch der
/// Keychain-Lookup-Schlüssel ist).
@Model
public final class TunnelInstance {
    /// Foreign Key auf den `TunnelTemplate` derselben UUID. Cross-Container-
    /// Relationships sind in SwiftData nicht möglich — das Repository
    /// joint zur Query-Zeit.
    public var templateID: UUID = UUID()

    /// Interface-Adressen, die der Server-Admin **diesem** Gerät zugewiesen
    /// hat. wg-quick-Strings, z.B. `["10.0.0.5/32", "fd00::5/128"]`.
    public var addresses: [String] = []

    /// Lokaler ListenPort — meist `nil` bei Client-Tunneln. `Int?` weil
    /// SwiftData `UInt16` nicht direkt mag.
    public var listenPort: Int?

    /// Optional: gerätespezifische MTU, überschreibt `TunnelTemplate.mtu`.
    /// `nil` heißt: Template-MTU verwenden.
    public var mtuOverride: Int?

    /// Erstellungszeitpunkt der lokalen Konfiguration — bei zweitem Gerät
    /// später als beim Template.
    public var configuredAt: Date = Date()

    public init(
        templateID: UUID = UUID(),
        addresses: [String] = [],
        listenPort: Int? = nil,
        mtuOverride: Int? = nil,
        configuredAt: Date = Date()
    ) {
        self.templateID = templateID
        self.addresses = addresses
        self.listenPort = listenPort
        self.mtuOverride = mtuOverride
        self.configuredAt = configuredAt
    }
}
