import Foundation
import SwiftUI
import Observation
import KabelwaechterCore
import KabelwaechterPersistence

extension Notification.Name {
    /// Lokale Repository-Mutation (claim / free / delete) — gleiche Idee wie
    /// auf iOS: die Liste hört darauf, statt nur auf den iCloud-Tick.
    static let kwLocalRepositoryChanged = Notification.Name("kw.localRepository.changed")
}

/// App-weite Abhängigkeiten der tvOS-App. Analog zu iOS-`CompanionAppEnvironment`,
/// aber wird in Phase 3.2 zusätzlich um den `TunnelManager` (NEVPNManager-
/// Wrapper) ergänzt.
@MainActor
@Observable
final class TVAppEnvironment {

    let repository: any TunnelRepositoring
    let tunnelManager: TunnelManager

    init(repository: any TunnelRepositoring) {
        self.repository = repository
        self.tunnelManager = TunnelManager(repository: repository)
    }

    // MARK: - Factories

    /// Production-Setup. CloudKit-Container-ID nur, wenn iCloud verfügbar ist
    /// (Decision #12 — P2). Auf Simulator immer lokal-only, weil unsigned
    /// Sim-Builds in CloudKit-Init crashen (gleiche Begründung wie iOS).
    @MainActor
    static func makeProduction() throws -> TVAppEnvironment {
        let container = try TunnelContainers.makeTunnelContainer(
            cloudKitContainerID: cloudKitContainerIDIfAvailable
        )
        let repo = TunnelRepository(container: container)
        return TVAppEnvironment(repository: repo)
    }

    @MainActor
    static func makePreview() -> TVAppEnvironment {
        let repo = InMemoryTunnelRepository()
        let sample = """
        [Interface]
        PrivateKey = qF1iY/zCm7XlGqXyDcUiPDV3rPdaYzVxq1jM5W3PJ2c=
        Address = 10.0.0.5/32
        DNS = 1.1.1.1

        [Peer]
        PublicKey = AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEE=
        AllowedIPs = 0.0.0.0/0, ::/0
        Endpoint = vpn.example.com:51820
        """
        _ = try? repo.importWgQuick(sample, named: "Heimnetz")
        return TVAppEnvironment(repository: repo)
    }

    /// CloudKit-Container nur auf echten Geräten — der Simulator-Build ist
    /// unsigniert (CODE_SIGNING_ALLOWED=NO), und ohne `icloud-services`-
    /// Entitlement crasht `PFCloudKitContainerProvider` mit `os_crash`.
    ///
    /// **Nicht** auf `FileManager.ubiquityIdentityToken` gaten — das prüft
    /// iCloud *Drive* und ist auf tvOS oft `nil`, obwohl iCloud/CloudKit
    /// funktionieren. SwiftData+CloudKit verträgt einen fehlenden Account
    /// auf signed Builds problemlos (queued bis Account da ist).
    private static var cloudKitContainerIDIfAvailable: String? {
#if targetEnvironment(simulator)
        return nil
#else
        return KabelwaechterConstants.iCloudContainerIdentifier
#endif
    }
}
