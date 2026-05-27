import Foundation

/// Identität *dieses* Geräts für die Tunnel-Zuweisung (Phase 7 / Milestone C).
///
/// Jede installierte App-Instanz (iPhone, iPad, Mac, Apple TV) ist ein eigenes
/// „Gerät" mit einer stabilen, lokal erzeugten `id` und einem **editierbaren
/// Namen**. Der Name wird beim Zuweisen eines Tunnels denormalisiert in den
/// `StoredTunnel` geschrieben (`ownerDeviceName`) und via CloudKit verteilt, so
/// dass andere Geräte die Section-Überschrift „<Gerätename>" anzeigen können.
///
/// Bewusst kein `UIDevice.name`/`Host.localizedName`: iOS/tvOS liefern seit
/// iOS 16 aus Datenschutzgründen nur generische Namen. Stattdessen vergibt
/// jedes Gerät seinen Namen selbst (Default = vom Aufrufer übergebener
/// Plattform-/Modellname, danach editierbar).
public enum DeviceIdentity {

    private static let defaults = UserDefaults.standard
    private static let idKey = "kw.device.id"
    private static let nameKey = "kw.device.name"

    /// Stabile, lokal persistierte Geräte-ID (UUID-String). Wird beim ersten
    /// Zugriff erzeugt und ändert sich danach nicht mehr.
    public static var id: String {
        if let existing = defaults.string(forKey: idKey) { return existing }
        let fresh = UUID().uuidString
        defaults.set(fresh, forKey: idKey)
        return fresh
    }

    /// Vom User gesetzter Gerätename (oder `nil`, solange keiner vergeben wurde).
    public static var name: String? {
        get { defaults.string(forKey: nameKey) }
        set {
            let trimmed = newValue?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let trimmed, !trimmed.isEmpty {
                defaults.set(trimmed, forKey: nameKey)
            } else {
                defaults.removeObject(forKey: nameKey)
            }
        }
    }

    /// Liefert den gesetzten Namen oder — beim ersten Mal — den `fallback`
    /// (z.B. „MacBook Pro", „iPhone"), den er dann persistiert.
    @discardableResult
    public static func resolvedName(default fallback: String) -> String {
        if let n = name { return n }
        name = fallback
        return fallback
    }
}
