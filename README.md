# Kabelwächter

Open-source WireGuard VPN client for **iPhone, iPad, Mac and Apple TV** —
tunnels sync between devices via iCloud, and every tunnel "belongs" to exactly
one device at a time. Beanspruchen, freigeben, einem anderen Gerät übergeben —
ein Klick.

> Powered by [WireGuard](https://www.wireguard.com/). WireGuard is a registered
> trademark of Jason A. Donenfeld.

## Status

**TestFlight-Beta live auf allen vier Plattformen.** App-Store-Submission ist
metadaten-vollständig (Listing-Texte DE/EN, Screenshots in 6.5"/6.7"/iPad/Mac,
App-Preview-Videos mit Brand-Intro), wartet nur noch auf den finalen „Submit
for Review"-Knopf.

| Plattform | Version | Beta-Link |
|---|---|---|
| iPhone / iPad | 1.0.3 (5) — APPROVED | <https://testflight.apple.com/join/23kyR7WK> |
| Apple TV | 1.0.3 (5) — APPROVED | <https://testflight.apple.com/join/Lz5L9Tdc> |
| Mac | 1.0.3 (6) — APPROVED | <https://testflight.apple.com/join/MaXh6Vy9> |

## Was Kabelwächter anders macht

Im Vergleich zur offiziellen WireGuard-App:

- **Apple TV — nativ.** Die offizielle WireGuard-App existiert für tvOS nicht.
  Kabelwächter ist eine eigenständige tvOS-App mit echter
  `NEPacketTunnelProvider`-Extension; Tunnel landen via iCloud auf dem TV,
  Verbinden ist ein Knopfdruck.
- **iCloud-Sync zwischen Geräten.** Tunnel, die du auf einem Gerät hinzufügst
  (QR-Scan / Datei / Paste), erscheinen via CloudKit Private Database auf den
  anderen Apple-Geräten desselben Accounts. Kein eigenes Cloud-Konto, kein
  Pairing, kein QR-zwischen-Geräten.
- **Owner-Modell — 1 Key = 1 Peer.** Jeder Tunnel gehört zur Laufzeit nur
  einem Gerät. Auf den anderen Geräten ist er als „in Verwendung auf
  <Geräte-Name>" sichtbar und claimbar. Verbinden ist nur am Besitzer-Gerät
  aktiv → keine Konflikte am WireGuard-Server, sauberer Hand-Over zwischen
  iPhone, Mac, iPad und TV.

Weiteres:

- Lokalisierung Deutsch (Quelle) + Englisch über `Localizable.xcstrings`-
  Kataloge pro Target.
- macOS-App ist Universal Binary (Apple Silicon + Intel), läuft im Hintergrund
  weiter, sobald das Hauptfenster geschlossen wird — Statusleisten-Icon zeigt
  Verbindungs-Zustand, Pulldown erlaubt Tunnel-Quickswitch ohne Hauptfenster.
- iPad bringt eine eigene Sidebar-+-Detail-Aufteilung mit (`NavigationSplitView`).
- Keine Analytics, keine Drittanbieter-SDKs, kein vom Entwickler betriebener
  Server. Tunnel-Daten leben in deiner privaten iCloud-Datenbank; Schlüssel
  liegen im Keychain mit `AccessibleAfterFirstUnlockThisDeviceOnly`.

## Architektur-Überblick

Drei App-Targets (iOS, macOS, tvOS), drei Network-Extensions, vier Swift-Package-
Libraries, ein WireGuard-Fork:

| Komponente | Rolle |
|---|---|
| `Kabelwaechter iOS` | iPhone + iPad mit `NavigationSplitView` für iPad-Idiom |
| `Kabelwaechter macOS` | Native Mac-App (eigenständig, **kein Catalyst**) inkl. `MenuBarExtra` |
| `Kabelwaechter tvOS` | „Centered Hub"-Design mit `focusSection`-Navigation |
| `KabelwaechterNEiOS` / `…tvOS` / `…mac` | `NEPacketTunnelProvider`-Appex-Targets, eine pro Plattform |
| `KabelwaechterCore` (SPM-Lib) | Domain-Typen (`TunnelConfiguration`, wg-quick-Parser, `DeviceIdentity`, `KeychainStore`) — **keine WireGuardKit-Dependency** |
| `KabelwaechterPersistence` (SPM-Lib) | SwiftData `StoredTunnel` `@Model` + `TunnelRepository`, CloudKit-Container-Factory, `InMemoryTunnelRepository` + `ScreenshotData` für Preview/Screenshots |
| `KabelwaechterUI` (SPM-Lib) | Design-System (Tokens, `TunnelViz`, `QRCodeView`, Button/Card-Styles, `CyberBackdrop`) |
| [`JxxKal/wireguard-apple-tvos`](https://github.com/JxxKal/wireguard-apple-tvos) | Fork von `natesinnott/wireguard-apple-tvos` mit `.iOS(.v17)`, `.tvOS(.v17)`, `.macOS(.v13)` |

Die `go-bridge` (`libwg-go.a`) wird per Run-Script-Phase pro Target gebaut
(macOS-Build erzeugt sie universal über `lipo`).

### Daten-Modell — Owner-Modell

Ein einzelnes `StoredTunnel`-Record pro Tunnel-ID in der iCloud-Privat-Datenbank
hält Interface- + Peer-Felder inkl. Address, Endpoint, AllowedIPs, MTU, DNS,
PSK. **Der Private Key** wird denormalisiert mit synchronisiert (siehe
[ADR-0003](docs/adr/0003-full-tunnel-sync.md)) und beim ersten Sync auf jedem
Gerät in die Keychain überführt.

Zusätzlich pro Tunnel:

- `ownerDeviceID` (`String?`) — UUID des Geräts, das den Tunnel gerade nutzt.
- `ownerDeviceName` (`String?`) — denormalisierter Geräte-Name für die Section-
  Überschrift („iPhone von Jan", „Wohnzimmer Apple TV").

Jede App-Instanz speichert ihre Identität in `DeviceIdentity` (lokaler
`UserDefaults`-UUID + editierbarer Name + `isNameConfirmed`-Flag — Pflicht-
Onboarding beim ersten Start).

## Repository-Layout

```
Kabelwaechter/
├── Kabelwaechter iOS/         Xcode-Projekt-Root
│   ├── Kabelwaechter iOS/     iOS-App-Sources (iPhone + iPad)
│   ├── Kabelwaechter tvOS/    tvOS-App-Sources
│   ├── Kabelwaechter macOS/   macOS-App-Sources (eigene Targets, classic group)
│   ├── KabelwaechterNEiOS/    iOS Network Extension
│   ├── KabelwaechterNEtvOS/   tvOS Network Extension
│   ├── KabelwaechterNEmac/    macOS Network Extension
│   └── Kabelwaechter.xcodeproj/
├── KabelwaechterCore/         Swift-Package (3 Library-Produkte)
│   ├── Sources/
│   │   ├── KabelwaechterCore/         (DeviceIdentity, Konstanten, Parser)
│   │   ├── KabelwaechterPersistence/  (SwiftData-Model, Repository, ScreenshotData)
│   │   └── KabelwaechterUI/           (Design-Tokens, Views)
│   └── Tests/                 41 Tests, decken Repository-Vertrag und wg-quick-Parser ab
├── Design/                    Logo-SVGs, Color-Tokens, App-Icon-Sources, Brand-Guide HTML
├── docs/adr/                  Architecture Decision Records (0001–0005)
├── PRIVACY.md / DATENSCHUTZ.md  App-Store-Privacy-Policy (EN + DE)
├── ExportOptions-AppStore.plist  altool-Distribution-Settings
├── scripts/sync-plan-to-wiki.py   syncs `Plan.md` → internes Wiki
└── README.md
```

`Plan.md` ist die aktuelle Arbeitsplanung, ist `.gitignore`'d — die kanonische
Plan-Version lebt im internen Wiki (Page 7).

## Voraussetzungen

- macOS 15 oder neuer
- Xcode 16 oder neuer
- Swift 6.0+
- Apple Developer Program (€99/Jahr — App-Groups, Network-Extensions, iCloud
  Container + CloudKit sind ohne Paid-Account nicht verfügbar)
- Für Apple-TV-Tests: Apple TV 4K (1. Gen, 2017) oder neuer mit tvOS 17+
- Für iPhone/iPad-Tests: iOS / iPadOS 17+
- Für Mac-Tests: macOS 14 (Sonoma) oder neuer

## Build & Run

Aus Xcode: Scheme wählen (`Kabelwaechter`, `Kabelwaechter macOS` oder
`Kabelwaechter tvOS`) + Ziel-Gerät + ⌘R. Die jeweilige Network-Extension wird
automatisch mit-embedded.

CLI-Beispiel für tvOS:

```bash
xcodebuild -project "Kabelwaechter iOS/Kabelwaechter.xcodeproj" \
           -scheme "Kabelwaechter tvOS" \
           -destination 'platform=tvOS,name=<Apple-TV-Name>' \
           -configuration Debug build
```

### Provisioning (einmalig)

In Apple Developer Portal müssen existieren:

- Bundle-IDs `de.jankaluza.kabelwaechter.{ios,tv,mac,ios.networkextension,
  tv.networkextension,mac.networkextension}` mit den jeweiligen
  Network-Extension-/App-Group-Capabilities
- App-Group `group.de.jankaluza.kabelwaechter.shared`
- iCloud-Container `iCloud.de.jankaluza.kabelwaechter.tunnels`

Erster Mac-Debug-Build muss einmal **über das Xcode-GUI** signiert werden
(Legacy-`developerservices2`-API lässt keine programmatische Profile-
Anlage zu); danach läuft `xcodebuild` mit dem gecachten Profile.

### Tunnel auf das Gerät bekommen

Zwei Wege:

- **iCloud-Sync (Standard).** Tunnel einmal in der App auf einem Gerät anlegen
  (`+` → QR-Scan / Datei / wg-quick-Paste). CloudKit syncht ihn inkl. Private
  Key innerhalb von Sekunden auf alle anderen Apple-Geräte desselben Accounts.
  Auf den anderen Geräten erscheint er als „frei" oder unter
  `<Gerätename>`-Section.
- **Manueller Import pro Gerät.** Auf jedem Gerät separat über `+` → wg-quick
  einfügen / Aus Datei…. Sinnvoll, wenn jedes Gerät ein eigener
  WireGuard-Peer sein soll (eigener Key, eigene Adresse).

### Verbinden

Tunnel anwählen → bei nicht beanspruchten Tunneln zuerst „Auf diesem Gerät
verwenden" → „Verbinden". Beim ersten Mal pro Plattform fragt iOS/macOS/tvOS
nach VPN-Konfigurations-Erlaubnis; bestätigen. Status wechselt
`Getrennt → Verbindet… → Verbunden`. Live-Stats (RX/TX/Last-Handshake) erscheinen
im Detail.

## Debugging

### Network-Extension-Logs

Logs sind mit `[KabelwaechterNE]` gepräfixt. Live-Tail vom Mac aus, während
das Gerät angesteckt/gepairt ist:

```bash
xcrun devicectl device process view --device <Geräte-Name> KabelwaechterNEtvOS
```

oder in Xcode → Fenster → Geräte und Simulatoren → Console.

### Häufige Fehler

| Symptom in Console | Wahrscheinliche Ursache |
|---|---|
| `kein wgQuickConfig in providerConfiguration` | `TunnelManager.connect` hat den Provider-Config nicht befüllt — meist weil der `StoredTunnel`-Record noch nicht vollständig synct ist (kein Private Key lokal). |
| `wgQuick-Parse fehlgeschlagen: invalidLine(…)` | Die eingefügte wg-quick enthält eine Zeile ohne Key=Value-Form. Quell-Config korrigieren, neu importieren. |
| `Core→WireGuardKit-Mapping fehlgeschlagen: invalidPrivateKey` | Der Curve25519-Key ist nach Base64-Decode nicht 32 Byte — Config ist defekt. |
| `WireGuardAdapter.start Fehler: cannotLocateTunnelFileDescriptor` | NE startete vor `NEPacketTunnelFlow` — meist transient, retry. Bei Persistenz: NE-Entitlements prüfen (App-Group + NetworkExtensions). |

### Lokaler Zustand zurücksetzen

System-Einstellungen → Netzwerk/VPN → Konfiguration entfernen → in der App
„Vom Gerät lösen" oder „Tunnel löschen". Re-Import zum Re-Test.

Der **NEVPN-Cleanup-Mechanismus** (Phase 7 / `cleanupOrphanedManagers`) räumt
beim App-Launch automatisch System-VPN-Configs auf, die laut Repository nicht
mehr diesem Gerät gehören (z. B. wenn ein anderes Gerät den Tunnel via iCloud
beansprucht hat).

## Datenschutz

Volle Privacy-Policy: [PRIVACY.md](PRIVACY.md) (EN) / [DATENSCHUTZ.md](DATENSCHUTZ.md) (DE).

Kurz: keine Analytics, keine Drittanbieter-SDKs, kein eigener Server. Tunnel-
Konfigurationen leben in deiner privaten iCloud-Datenbank, Private Keys in der
Keychain. Geräte-Identität (UUID + editierbarer Name) ebenfalls in iCloud-Privat
für die Owner-Sections auf anderen Apple-Geräten.

## Lizenz

MIT.
