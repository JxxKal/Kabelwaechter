# Voller Tunnel-Sync: ein StoredTunnel inkl. PrivateKey via CloudKit

Löst [ADR-0001](0001-tunnel-template-instance-split.md) (und damit den Kern von
Decision #9, "Per-Device-Keypair") ab. Ein Tunnel wird nicht mehr in einen
gerätegeteilten `TunnelTemplate` (CloudKit) und einen gerätelokalen
`TunnelInstance` (lokal, ohne PrivateKey) gespalten. Stattdessen gibt es **ein**
SwiftData-`@Model` `StoredTunnel`, das die komplette wg-quick-Config — inklusive
`Interface.Address` und `PrivateKey` — hält und als Ganzes via CloudKit
Private-Database zwischen allen Geräten desselben Apple-Accounts synchronisiert.

**Warum.** Der Split existierte allein, um Per-Device-Geheimnisse aus iCloud
rauszuhalten. Das löste aber ein Problem, das der reale Nutzungsfall nicht hat:
Der User bekommt *eine* wg-quick-Config, importiert sie *einmal* in der
iPhone-Companion-App und erwartet, dass sie auf dem Apple TV verbindungsbereit
erscheint — ohne auf dem TV (ohne Bluetooth-Tastatur) Teile der Config
nachzutippen. Die iOS-App verbindet selbst nie (Decision #8 — kein
VPN-Entitlement), ist also nie ein WireGuard-Peer; und bei genau einem Apple TV
gibt es ohnehin nur eine Peer-Identität. Der „shared key = Peer-Kollision"-
Fallstrick, gegen den Decision #9 schützte, tritt erst bei **mehreren
gleichzeitig verbundenen** Apple TVs auf. Für diesen Fall bleibt der manuelle
wg-quick-Import auf dem Zweitgerät als Notausgang: er legt einen separaten
`StoredTunnel` mit eigener Identität an.

**PrivateKey im Modell statt Keychain.** Der Key syncht als `Data`-Feld des
`StoredTunnel` über dieselbe CloudKit-Pipeline wie der Rest — eine Pipeline,
atomar (der Key kommt mit dem Record), kein zweiter Sync-Kanal, kein
Keychain-Sharing-Entitlement auf der iOS-App. Die Network Extension liest den
Key ohnehin nicht aus dem Keychain, sondern bekommt die fertige wg-quick-Config
als String über `NETunnelProviderProtocol.providerConfiguration`
(`TunnelManager.connect`). Der `KeychainStore` aus Phase 2.2 bleibt als
getestete, generische Core-Komponente erhalten, ist aber nicht mehr in den
Repository-Pfad verdrahtet.

**Trade-off (Sicherheit).** CloudKit Private-Database ist in Transit und at-rest
verschlüsselt, aber mit Apple-verwalteten Schlüsseln — Ende-zu-Ende nur, wenn der
User Advanced Data Protection aktiviert (dann sind gleich alle CloudKit-Daten
E2E). Die strikt-E2E-Alternative (PrivateKey via iCloud-Keychain) wurde
verworfen: sie hätte ein Keychain-Sharing-Entitlement plus Redeploy der
iOS-App, zwei unabhängige Sync-Pipelines mit Timing-Lücke und die auf tvOS
trägere iCloud-Keychain-Synchronisierung gekostet. Für ein selbstgehostetes
Heim-VPN ist das Threat-Model mild; wer mehr will, schaltet ADP ein.

**Folgen.** Nur noch ein `ModelContainer` (`TunnelContainers.makeTunnelContainer`).
`TunnelRepository` braucht keinen `KeychainStoring` mehr. `attachInstance` und der
tvOS-„Auf diesem Apple TV einrichten"-Flow entfallen ersatzlos. `isConfiguredHere`
bedeutet jetzt schlicht „PrivateKey vorhanden" und ist nach dem Sync ~immer wahr.
Schema-Änderung ⇒ bereits gesyncte Records des alten Schemas müssen einmalig
gelöscht werden.
