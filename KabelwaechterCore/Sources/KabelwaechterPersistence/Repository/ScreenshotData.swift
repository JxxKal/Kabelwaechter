import Foundation
import KabelwaechterCore

/// Bestückt eine `InMemoryTunnelRepository` mit kuratierten Demo-Tunneln für
/// App-Store-Screenshots. Wird nur beim Launch-Argument `--screenshots`
/// gerufen — Production läuft unverändert über `makeProduction()`.
///
/// Erzeugt vier Tunnel mit verschiedenen Besitzern, damit alle Owner-Sections
/// (Meine Tunnel / Frei / <Geräte-Name>) gleichzeitig zu sehen sind:
///
/// - **Home** — Owner: „John's iPhone"
/// - **Office VPN** — Owner: „John's Mac"
/// - **Streaming** — Owner: „Living Room Apple TV"
/// - **Travel VPN** — frei (kein Besitzer)
///
/// Der Aufrufer übergibt den eigenen Geräte-Namen + den Namen des Tunnels,
/// der diesem Gerät gehört (`myOwnedTunnelName`); die anderen drei behalten
/// ihren fixen Besitzer. So sieht jede Plattform ihre passende „Mine"-Section.
@MainActor
public enum ScreenshotData {

    /// Synthetische wg-quick-Config pro Demo-Tunnel-Name. Wird von
    /// `InMemoryTunnelRepository.displayConfiguration(id:)` benutzt, damit
    /// die Detail-View im Screenshot-/Preview-Modus statt der echten Keys/
    /// Endpoints maskierte Werte anzeigt.
    public static func displayWgQuick(for tunnelName: String) -> String {
        struct D { let address: String; let endpoint: String; let allowedIPs: String }
        let m: [String: D] = [
            "Home":       D(address: "10.0.0.5/32",  endpoint: "home.example.com:51820",   allowedIPs: "0.0.0.0/0, ::/0"),
            "Office VPN": D(address: "10.0.0.6/32",  endpoint: "office.example.com:51820", allowedIPs: "10.0.0.0/24"),
            "Streaming":  D(address: "10.0.0.7/32",  endpoint: "stream.example.com:51820", allowedIPs: "0.0.0.0/0, ::/0"),
            "Travel VPN": D(address: "10.0.0.8/32",  endpoint: "travel.example.com:51820", allowedIPs: "0.0.0.0/0, ::/0"),
        ]
        let d = m[tunnelName] ?? D(address: "10.0.0.99/32",
                                    endpoint: "example.com:51820",
                                    allowedIPs: "0.0.0.0/0")
        return """
        [Interface]
        PrivateKey = qF1iY/zCm7XlGqXyDcUiPDV3rPdaYzVxq1jM5W3PJ2c=
        Address = \(d.address)
        DNS = 1.1.1.1
        MTU = 1420

        [Peer]
        PublicKey = AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEE=
        AllowedIPs = \(d.allowedIPs)
        Endpoint = \(d.endpoint)
        PersistentKeepalive = 21
        """
    }

    /// Reale wg-quick-Configs pro Tunnel-Name für App-Preview-**Videos** —
    /// wenn ein Eintrag existiert, wird er statt der synthetischen Config
    /// benutzt, sodass die Verbindung tatsächlich aufgebaut werden kann
    /// (echte Handshake-/RX-/TX-Zahlen in der Aufnahme). Der **angezeigte**
    /// Endpoint bleibt der maskierte Demo-Wert (`*.example.com`) — der echte
    /// Server wird nur in der Network-Extension benutzt, nie im UI.
    ///
    /// NICHT mit echten Schlüsseln committen. Lokal befüllen, nach Aufnahme
    /// auf `[:]` zurücksetzen.
    public static var realConfigs: [String: String] = [:]

    public static func seedRepository(deviceName: String, myOwnedTunnelName: String) -> InMemoryTunnelRepository {
        DeviceIdentity.name = deviceName
        DeviceIdentity.isNameConfirmed = true

        let repo = InMemoryTunnelRepository()
        let me = DeviceIdentity.id

        struct Demo {
            let name: String
            let address: String
            let endpoint: String
            let ownerDeviceID: String?
            let ownerDeviceName: String?
        }
        let demos: [Demo] = [
            Demo(name: "Home", address: "10.0.0.5/32",
                 endpoint: "home.example.com:51820",
                 ownerDeviceID: "demo-iphone", ownerDeviceName: "John's iPhone"),
            Demo(name: "Office VPN", address: "10.0.0.6/32",
                 endpoint: "office.example.com:51820",
                 ownerDeviceID: "demo-mac", ownerDeviceName: "John's Mac"),
            Demo(name: "Streaming", address: "10.0.0.7/32",
                 endpoint: "stream.example.com:51820",
                 ownerDeviceID: "demo-tv", ownerDeviceName: "Living Room Apple TV"),
            Demo(name: "Travel VPN", address: "10.0.0.8/32",
                 endpoint: "travel.example.com:51820",
                 ownerDeviceID: nil, ownerDeviceName: nil),
        ]

        for d in demos {
            let isMine = (d.name == myOwnedTunnelName)
            let wg: String
            if let real = Self.realConfigs[d.name], !real.isEmpty {
                // Echter Tunnel für diesen Slot → echte Connection möglich
                // (auch für nicht-eigene; falls der User in der Aufnahme
                // einen freien Tunnel claimt + verbindet).
                wg = real
            } else {
                wg = """
                [Interface]
                PrivateKey = qF1iY/zCm7XlGqXyDcUiPDV3rPdaYzVxq1jM5W3PJ2c=
                Address = \(d.address)
                DNS = 1.1.1.1

                [Peer]
                PublicKey = AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEE=
                AllowedIPs = 0.0.0.0/0, ::/0
                Endpoint = \(d.endpoint)
                """
            }
            guard let id = try? repo.importWgQuick(wg, named: d.name) else { continue }
            // Anzeige-Endpoint immer auf den Demo-Wert maskieren — bei der
            // synthetischen Variante ist's eh derselbe Wert, beim echten
            // Tunnel verschwindet so die reale Server-Adresse aus dem UI.
            repo.setDisplayEndpoint(d.endpoint, forTunnelID: id)
            if isMine {
                try? repo.assign(tunnelID: id, toDeviceID: me, named: deviceName)
            } else if let did = d.ownerDeviceID, let dname = d.ownerDeviceName {
                try? repo.assign(tunnelID: id, toDeviceID: did, named: dname)
            }
        }
        return repo
    }
}
