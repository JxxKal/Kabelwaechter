# iOS-VPN aktiviert + Tunnel-Ziel-Modell (phone | appleTV)

Revidiert **Decision #8** („iOS-App ist reiner Companion-Editor, kein VPN").
Das iPhone baut WireGuard-Tunnel jetzt selbst auf. Damit beide Plattformen im
selben (voll gesyncten, ADR-0003) Tunnel-Bestand sinnvoll koexistieren, bekommt
jeder Tunnel ein **Zielgerät**.

## iOS-VPN
- Neues iOS-NE-Target `KabelwaechterNEiOS` (`NEPacketTunnelProvider`,
  Source-Klon der tvOS-NE), eingebettet in die iOS-App, linkt WireGuardKit +
  `libwg-go.a`. Go-Bridge-Build siehe ADR-0005.
- Entitlements an iOS-App **und** iOS-NE: App Group, Keychain-Sharing,
  `com.apple.developer.networking.networkextension` (packet-tunnel-provider),
  Personal VPN (`…vpn.api` allow-vpn) — gespiegelt vom tvOS-Schema. Erfordert
  die entsprechenden Capabilities auf den App-IDs `…ios` und
  `…ios.networkextension` im Developer-Portal.
- iOS-`TunnelManager` (identisch zur tvOS-Variante, Provider =
  iOS-NE-Bundle-ID): connect/disconnect, per-Tunnel Auto-Connect (On-Demand),
  Live-Stats. UI: Connect-Panel im iOS-Detail.

**Warum die Umkehr:** Der ursprüngliche Editor-only-Ansatz (Decision #8) war
„future-proof für später". Die iOS-NE samt Go-Bridge ist mit dem bestehenden
Fork ohne Sonderaufwand baubar (iOS ist der native WireGuard-Zielfall), also
gibt es keinen Grund, das iPhone vom Verbinden auszuschließen.

## Tunnel-Ziel (Rolle)
`StoredTunnel.target: TunnelTarget` ∈ {`phone`, `appleTV`}.
- **Default `appleTV`** — so bleiben CloudKit-Bestandsdaten (vor diesem ADR)
  Apple-TV-Tunnel; nichts verschwindet von der TV.
- **iOS-Import → `phone`**, tvOS-Import → `appleTV`.
- **iOS-Liste**: zwei Sektionen — „Meine Tunnel" (phone, hier verbindbar) und
  separiert „Apple TV" (appleTV, hier nicht verbindbar, tv-Symbol).
- **tvOS-Hub**: zeigt/verbindet **nur** `appleTV`-Tunnel.
- **Aktion „Auf Apple TV verschieben" / „Auf iPhone zurückholen"** (`setTarget`)
  im iOS-Detail. Bewusst **Verschieben statt Kopieren**: WireGuard-Regel
  „ein Key = ein Peer". Derselbe Key gleichzeitig auf iPhone **und** TV
  verbunden → Peer-Identitäts-Kollision. Ein Ziel pro Tunnel vermeidet das.
  Echtes „Kopieren" bräuchte ein eigenes Keypair fürs Zweitgerät (verworfen,
  zu viel Aufwand + Server-Eintrag).

**Folgen:** `importWgQuick(…, target:)` (2-arg-Convenience-Default `.appleTV`),
`setTarget(_:forTunnelID:)`, `TunnelView.target`; `updateTunnel` erhält das
Ziel. Status-Punkt auf iOS = echte Verbindung (grün) statt pauschalem Grün;
Status-Viz erscheint, wenn ein phone-Tunnel verbunden ist.
