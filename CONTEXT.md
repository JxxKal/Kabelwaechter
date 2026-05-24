# Kabelwächter

WireGuard-VPN-Client für Apple TV (tvOS) mit iOS-Companion-Editor. Tunnel-Konfigurationen werden lokal-zuerst gespeichert und (optional) zwischen Geräten via CloudKit synchronisiert.

## Language

### Tunnel-Konfiguration

**StoredTunnel**:
Die **vollständige** persistierte Tunnel-Konfiguration: Display-Name, Server-Daten (Peer-PublicKey, Endpoint, AllowedIPs, PresharedKey, PersistentKeepalive), Interface-Daten (PrivateKey, Address, DNS, MTU, ListenPort). Ein einziges SwiftData-`@Model`, das als Ganzes via CloudKit zwischen allen Geräten desselben Apple-Accounts synchronisiert wird. Seit ADR-0003 — löste den früheren TunnelTemplate/TunnelInstance-Split (ADR-0001) ab.
_Avoid_: "Tunnel-Metadaten", "TunnelTemplate", "TunnelInstance"

**Tunnel**:
Die Sicht-auf-einen-Tunnel aus User-Perspektive — entspricht genau einem **StoredTunnel**. Auf jedem Gerät identisch, weil der komplette Tunnel synct. Ein zweites Apple TV, das eine *eigene* Identität (eigenen PrivateKey/Address) braucht, bekommt einen separaten **StoredTunnel** via manuellen wg-quick-Import.
_Avoid_: "VPN-Eintrag", "Connection"

**wg-quick-Config**:
Das Text-Format `[Interface]\n…\n[Peer]\n…`, das WireGuard-Tools (wg-quick) lesen und schreiben. Quelle für den Import **und** das Format, in dem die Config an die Network Extension übergeben wird (via `providerConfiguration`). Der Parser lebt in `KabelwaechterCore`.
_Avoid_: "Tunnel-Datei", "VPN-Config"

### Schlüsselmaterial

**PrivateKey**:
Curve25519-Private-Key (32 Byte) für die `[Interface]`-Sektion. Teil des **StoredTunnel** und syncht mit (ADR-0003) — damit ein einmal importierter Tunnel auf allen Geräten sofort verbindungsbereit ist. At-rest geschützt durch SwiftData/CloudKit; E2E nur mit aktivierter Advanced Data Protection.
_Avoid_: "Tunnel-Schlüssel" (zu unspezifisch — siehe **PresharedKey**)

**PublicKey** (vom Server / Peer):
Curve25519-Public-Key (32 Byte) für die `[Peer]`-Sektion — identifiziert den Remote-VPN-Server. Geteilt via **TunnelTemplate**.

**PresharedKey** (optional):
Symmetrischer 32-Byte-Zusatzschlüssel. Beide Seiten brauchen denselben Wert. Wird via CloudKit synchronisiert (verschlüsselt durch CloudKit-Layer), weil ohne Sync der PSK über Geräte hinweg nicht funktioniert. Teil von **TunnelTemplate**.

## Relationships

- Ein **Tunnel** = genau ein **StoredTunnel** (kein Split mehr)
- Eine **wg-quick-Config** wird beim Import in genau ein **StoredTunnel** umgewandelt (`TunnelConfiguration.toStoredTunnel`)
- Ein **StoredTunnel** enthält den **PrivateKey** direkt (keine Keychain-Referenz im Repo-Pfad)
- Mehrere Apple TVs mit *eigenen* Identitäten = mehrere **StoredTunnel** (je ein manueller Import)

## Example dialogue

> **Dev:** "Wenn der User auf dem Apple-TV einen Tunnel sieht, der vom iPhone via CloudKit kam — was sieht er konkret?"
> **Domain expert:** "Er sieht den **StoredTunnel** mit Display-Name, und er ist sofort verbindungsbereit, weil der komplette Tunnel inkl. **PrivateKey** synct. Nur in der kurzen Lücke, bevor der CloudKit-Record ganz angekommen ist, zeigt das Detail 'iCloud-Sync läuft'. Will jemand ein *zweites* Apple TV als getrennten WireGuard-Peer (eigener Key, damit beide gleichzeitig verbinden können, ohne sich die Peer-Identität streitig zu machen), importiert er dort manuell eine separate wg-quick-Config."

## Flagged ambiguities

- "Tunnel-Metadaten" wurde in Plan §85/Entscheidung 9 verwendet, ist aber zu vage. Heute: alles steckt in **StoredTunnel**.
- "Tunnel-Schlüssel" könnte **PrivateKey** oder **PresharedKey** meinen — beide kommen vor, beide sind 32 Byte. Im Code immer den spezifischen Namen verwenden.
- **TunnelTemplate** / **TunnelInstance**: historische Begriffe (ADR-0001), seit ADR-0003 **obsolet** — nicht mehr verwenden.
