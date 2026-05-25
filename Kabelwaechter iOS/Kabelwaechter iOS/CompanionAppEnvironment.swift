import Foundation
import SwiftUI
import Observation
import KabelwaechterCore
import KabelwaechterPersistence

/// Bündelt alle App-weiten Abhängigkeiten der iOS-Companion-App in einer
/// Observable-Klasse, die per `.environment(...)` in den View-Tree gehängt
/// und in Views via `@Environment(CompanionAppEnvironment.self)` konsumiert
/// wird.
///
/// Phase 2.6 hält nur die `TunnelRepository`-Referenz. Spätere Phasen
/// können CloudKit-Account-Status, Online-State o.ä. dazustellen.
@MainActor
@Observable
final class CompanionAppEnvironment {

    /// Zugang zu Tunneln. Production: SwiftData-backed `TunnelRepository`
    /// mit CloudKit-Container. Preview/Test: `InMemoryTunnelRepository`.
    let repository: any TunnelRepositoring
    /// VPN-Steuerung — seit der iOS-NE kann das iPhone phone-Tunnel selbst
    /// aufbauen (Decision #8 revidiert).
    let tunnelManager: TunnelManager

    init(repository: any TunnelRepositoring) {
        self.repository = repository
        self.tunnelManager = TunnelManager(repository: repository)
    }

    // MARK: - Factories

    /// Production-Setup: ein SwiftData-ModelContainer (`StoredTunnel`,
    /// optional CloudKit-gesynct).
    ///
    /// CloudKit-Verhalten folgt Decision #12 (P2 — iCloud-optional):
    /// auf dem Simulator ohne signed entitlements oder ohne iCloud-Account
    /// würde die CoreData/CloudKit-Mirroring-Initialisierung `os_crash`
    /// auslösen — wir laufen dort lokal-only. Auf signed Builds mit
    /// iCloud-Account sync't der Tunnel-Store via Private-Database.
    @MainActor
    static func makeProduction() throws -> CompanionAppEnvironment {
        let container = try TunnelContainers.makeTunnelContainer(
            cloudKitContainerID: cloudKitContainerIDIfAvailable
        )
        let repo = TunnelRepository(container: container)
        return CompanionAppEnvironment(repository: repo)
    }

    /// Liefert die iCloud-Container-ID nur dann, wenn CloudKit auf diesem
    /// Build/Gerät überhaupt sicher initialisierbar ist:
    /// - **Simulator**: nie (Sim-Builds ohne signed entitlements crashen
    ///   in `PFCloudKitContainerProvider`).
    /// - **Device**: nur wenn der User in iCloud signed-in ist
    ///   (`FileManager.ubiquityIdentityToken != nil`).
    /// CloudKit-Container nur auf echten Geräten — Simulator-Build ist
    /// unsigniert und crasht ohne `icloud-services`-Entitlement. **Nicht**
    /// auf `ubiquityIdentityToken` gaten (das ist iCloud Drive, nicht
    /// CloudKit). SwiftData+CloudKit verträgt fehlenden Account auf signed
    /// Builds.
    private static var cloudKitContainerIDIfAvailable: String? {
#if targetEnvironment(simulator)
        return nil
#else
        return KabelwaechterConstants.iCloudContainerIdentifier
#endif
    }

    /// Preview/Demo-Setup mit InMemory-Repository und ein paar Sample-Tunneln.
    @MainActor
    static func makePreview() -> CompanionAppEnvironment {
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
        return CompanionAppEnvironment(repository: repo)
    }
}
