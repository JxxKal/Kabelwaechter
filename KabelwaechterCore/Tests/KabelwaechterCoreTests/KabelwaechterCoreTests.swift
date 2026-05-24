import Testing
@testable import KabelwaechterCore

@Suite("KabelwaechterConstants")
struct KabelwaechterConstantsTests {

    @Test("App Group identifier ist korrekt strukturiert")
    func appGroupIdentifierStructure() {
        #expect(KabelwaechterConstants.appGroupIdentifier == "group.de.jankaluza.kabelwaechter.shared")
        #expect(KabelwaechterConstants.appGroupIdentifier.hasPrefix("group."))
    }

    @Test("iCloud Container ist korrekt strukturiert")
    func iCloudContainerStructure() {
        #expect(KabelwaechterConstants.iCloudContainerIdentifier == "iCloud.de.jankaluza.kabelwaechter.tunnels")
        #expect(KabelwaechterConstants.iCloudContainerIdentifier.hasPrefix("iCloud."))
    }

    @Test("Alle Bundle-IDs teilen den vereinbarten Präfix")
    func bundleIdPrefix() {
        let prefix = KabelwaechterConstants.BundleIdentifiers.prefix + "."
        #expect(KabelwaechterConstants.BundleIdentifiers.iOSApp.hasPrefix(prefix))
        #expect(KabelwaechterConstants.BundleIdentifiers.tvOSApp.hasPrefix(prefix))
        #expect(KabelwaechterConstants.BundleIdentifiers.iOSNetworkExtension.hasPrefix(prefix))
        #expect(KabelwaechterConstants.BundleIdentifiers.tvOSNetworkExtension.hasPrefix(prefix))
    }

    @Test("Network-Extension-IDs sind Sub-Identifier ihrer App-IDs (Apple-Vorschrift)")
    func networkExtensionExtendsAppId() {
        #expect(
            KabelwaechterConstants.BundleIdentifiers.iOSNetworkExtension
                .hasPrefix(KabelwaechterConstants.BundleIdentifiers.iOSApp + ".")
        )
        #expect(
            KabelwaechterConstants.BundleIdentifiers.tvOSNetworkExtension
                .hasPrefix(KabelwaechterConstants.BundleIdentifiers.tvOSApp + ".")
        )
    }

    @Test("Alle Identifier sind lowercase")
    func allLowercase() {
        let identifiers = [
            KabelwaechterConstants.appGroupIdentifier,
            KabelwaechterConstants.keychainSharingGroup,
            KabelwaechterConstants.iCloudContainerIdentifier,
            KabelwaechterConstants.BundleIdentifiers.iOSApp,
            KabelwaechterConstants.BundleIdentifiers.tvOSApp,
            KabelwaechterConstants.BundleIdentifiers.iOSNetworkExtension,
            KabelwaechterConstants.BundleIdentifiers.tvOSNetworkExtension
        ]
        for id in identifiers {
            // iCloud-Container darf "iCloud." mit Großbuchstabe enthalten — Apple-Konvention,
            // alles dahinter muss aber lowercase sein.
            let withoutICloudPrefix = id.hasPrefix("iCloud.") ? String(id.dropFirst("iCloud.".count)) : id
            #expect(withoutICloudPrefix == withoutICloudPrefix.lowercased(), "Identifier \(id) ist nicht durchgängig lowercase")
        }
    }
}
