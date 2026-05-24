# Tunnel-Persistenz: TunnelTemplate (CloudKit) + TunnelInstance (lokal) in zwei ModelContainern

> **⚠️ ABGELÖST durch [ADR-0003](0003-full-tunnel-sync.md) (2026-05-24).** Der hier
> beschriebene Template/Instance-Split wurde aufgegeben: der komplette Tunnel inkl.
> PrivateKey syncht jetzt via CloudKit (ein `StoredTunnel`-Modell). Dieses Dokument
> bleibt als historische Begründung erhalten — der beschriebene Zustand ist **nicht
> mehr aktuell**.

Architektur-Entscheidung #9 ("Per-Device-Keypair, CloudKit syncs nur Metadaten") wurde
in Phase 2.3 konkretisiert: ein **Tunnel** zerfällt persistenz-seitig in einen
gerätegeteilten **TunnelTemplate** (Display-Name, Server-PublicKey, Server-Endpoint,
AllowedIPs, PSK, DNS, MTU, PersistentKeepalive) und einen gerätelokalen
**TunnelInstance** (Interface.Address, ListenPort, MTU-Override). Beide sind eigene
SwiftData `@Model`-Klassen in **zwei getrennten `ModelContainer`n** — `templates`
mit `cloudKitDatabase: .private`, `instances` mit `.none`. Verknüpft werden sie zur
Query-Zeit über die geteilte Tunnel-UUID; cross-container Relationships gibt's in
SwiftData nicht und sind hier auch unerwünscht. Die strukturelle Trennung garantiert,
dass per-Device-Geheimnisse (Address vom Server-Pool, Keychain-Referenz) niemals
versehentlich in iCloud landen können — Disziplin allein hätte das nicht garantiert,
weil ein gemeinsamer Container mit `cloudKitDatabase: .private` immer alle Modelle
mitsyncen würde. Der `PrivateKey` selbst liegt nicht in SwiftData, sondern im
Keychain (siehe Phase 2.2 / `KabelwaechterCore.KeychainStore`). Trade-off: keine
einzige `@Query` kann den vollständigen Tunnel zeigen — die UI muss zwei Queries
mergen, vermittelt durch `TunnelRepository` (`@MainActor`).
