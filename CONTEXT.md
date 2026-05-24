# Kabelwächter

WireGuard-VPN-Client für Apple TV (tvOS) mit iOS-Companion-Editor. Tunnel-Konfigurationen werden lokal-zuerst gespeichert und (optional) zwischen Geräten via CloudKit synchronisiert.

## Language

### Tunnel-Konfiguration

**TunnelTemplate**:
Der zwischen Geräten geteilte Teil einer Tunnel-Konfiguration: Display-Name, Server-Daten (Peer-PublicKey, Endpoint, AllowedIPs, PresharedKey, PersistentKeepalive), netzwerkweite Interface-Einstellungen (DNS, MTU). Wird via CloudKit zwischen Geräten synchronisiert.
_Avoid_: "Tunnel-Metadaten", "Tunnel-Config"

**TunnelInstance**:
Der gerätelokale Teil einer Tunnel-Konfiguration: Interface.PrivateKey (im Keychain), Interface.Address (vom Server-Admin per-Device vergeben), Interface.ListenPort (selten gesetzt). Existiert auf jedem Gerät, das den Tunnel aktiv nutzt. Wird NIEMALS via CloudKit synchronisiert.
_Avoid_: "Device-Config", "Local-Tunnel"

**Tunnel**:
Die Sicht-auf-einen-Tunnel aus User-Perspektive — die Kombination aus genau einem **TunnelTemplate** und (höchstens einem) lokalen **TunnelInstance**. Auf einem Gerät, das den Tunnel noch nicht eingerichtet hat, gibt es das TunnelTemplate ohne TunnelInstance (Status: "muss auf diesem Gerät konfiguriert werden").
_Avoid_: "VPN-Eintrag", "Connection"

**wg-quick-Config**:
Das Text-Format `[Interface]\n…\n[Peer]\n…`, das WireGuard-Tools (wg-quick) lesen und schreiben. Quelle für den Import; nicht für interne Persistenz verwendet. Der Parser lebt in `KabelwaechterCore`.
_Avoid_: "Tunnel-Datei", "VPN-Config"

### Schlüsselmaterial

**PrivateKey**:
Curve25519-Private-Key (32 Byte) für die `[Interface]`-Sektion. **Per-Device**, nie synchronisiert. Liegt im Keychain mit Access-Level `AfterFirstUnlockThisDeviceOnly`, adressiert per Tunnel-UUID. Decision-#9.
_Avoid_: "Tunnel-Schlüssel" (zu unspezifisch — siehe **PresharedKey**)

**PublicKey** (vom Server / Peer):
Curve25519-Public-Key (32 Byte) für die `[Peer]`-Sektion — identifiziert den Remote-VPN-Server. Geteilt via **TunnelTemplate**.

**PresharedKey** (optional):
Symmetrischer 32-Byte-Zusatzschlüssel. Beide Seiten brauchen denselben Wert. Wird via CloudKit synchronisiert (verschlüsselt durch CloudKit-Layer), weil ohne Sync der PSK über Geräte hinweg nicht funktioniert. Teil von **TunnelTemplate**.

## Relationships

- Ein **Tunnel** = ein **TunnelTemplate** + höchstens ein **TunnelInstance** pro Gerät
- **TunnelTemplate** ↔ **TunnelInstance** sind über die Tunnel-UUID verknüpft
- Ein **TunnelInstance** referenziert genau einen **PrivateKey** im Keychain (per Tunnel-UUID)
- Eine **wg-quick-Config** wird beim Import in genau ein **TunnelTemplate** + ein **TunnelInstance** aufgespalten

## Example dialogue

> **Dev:** "Wenn der User auf dem Apple-TV einen neuen Tunnel sieht, der vom iPhone via CloudKit kam — was sieht er konkret?"
> **Domain expert:** "Er sieht den **TunnelTemplate** in der Liste mit dem Display-Name, aber als 'nicht eingerichtet'. Es fehlt der **TunnelInstance**: kein **PrivateKey** im lokalen Keychain, keine `Interface.Address`. Er muss aktiv 'Tunnel auf diesem Gerät einrichten' antippen und entweder eine neue wg-quick-Config einlesen, die der Server-Admin für dieses zweite Gerät erstellt hat, oder eine Keypair generieren und den Public Key dem Admin geben."

## Flagged ambiguities

- "Tunnel-Metadaten" wurde in Plan §85/Entscheidung 9 verwendet, ist aber zu vage. Aufgelöst in **TunnelTemplate** vs **TunnelInstance**.
- "Tunnel-Schlüssel" könnte **PrivateKey** oder **PresharedKey** meinen — beide kommen vor, beide sind 32 Byte. Im Code immer den spezifischen Namen verwenden.
