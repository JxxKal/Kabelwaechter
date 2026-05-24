import Foundation

/// Zentrale Konstanten für Bundle-Identifiers, App-Group, Keychain-Sharing-Group
/// und iCloud-Container von Kabelwaechter. Wird sowohl von der App-Seite
/// (iOS/tvOS Apps) als auch der Network-Extension-Seite (tvOS NE) gelesen.
public enum KabelwaechterConstants {

    /// App Group für gemeinsamen Container-Zugriff zwischen tvOS-App und tvOS-NE.
    /// Auf iOS-Seite nicht genutzt (iOS-App hat keine NE in Phase 1).
    public static let appGroupIdentifier = "group.de.jankaluza.kabelwaechter.shared"

    /// Keychain Access Group für geteilten Keychain-Zugriff zwischen tvOS-App und tvOS-NE
    /// (Secrets wie Private Keys liegen hier). Auf iOS-Seite nicht genutzt.
    public static let keychainSharingGroup = "de.jankaluza.kabelwaechter.shared"

    /// iCloud Container für CloudKit-Sync der Tunnel-Metadaten (nicht der Private Keys —
    /// Per-Device-Identität, siehe Architektur-Entscheidung 9).
    public static let iCloudContainerIdentifier = "iCloud.de.jankaluza.kabelwaechter.tunnels"

    /// Bundle Identifiers für die einzelnen Targets. Müssen exakt zu den
    /// im Apple Developer Portal registrierten App-IDs passen.
    public enum BundleIdentifiers {
        /// iOS Companion-Editor-App
        public static let iOSApp = "de.jankaluza.kabelwaechter.ios"

        /// iOS Network Extension — in Phase 1 nur als Namespace reserviert,
        /// kein Xcode-Target. Wird aktiv, sobald iOS-VPN-Support gebaut wird.
        public static let iOSNetworkExtension = "de.jankaluza.kabelwaechter.ios.networkextension"

        /// tvOS VPN-Haupt-App
        public static let tvOSApp = "de.jankaluza.kabelwaechter.tv"

        /// tvOS Network Extension (Packet Tunnel Provider) — der eigentliche VPN-Code
        public static let tvOSNetworkExtension = "de.jankaluza.kabelwaechter.tv.networkextension"

        /// Gemeinsamer Reverse-DNS-Präfix aller Bundle-IDs
        public static let prefix = "de.jankaluza.kabelwaechter"
    }
}
