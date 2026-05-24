# Persistenz als separates Sub-Target im Core-Package

Die SwiftData-`@Model`-Klassen, beide `ModelContainer`-Factories und das
`TunnelRepository` leben in einem neuen Sub-Target `KabelwaechterPersistence` im
selben SwiftPM-Package wie `KabelwaechterCore`, **nicht** im Core selbst.
`KabelwaechterCore` bleibt damit infrastrukturfrei — pure Domain-Typen (structs),
wg-quick-Parser, Key-Validator, KeychainStore-Protokoll. `KabelwaechterPersistence`
hängt von Core ab und enthält alles SwiftData/CloudKit-spezifische. Apps linken
beide Products. Folgen: (1) Core-Tests bleiben schnell und SwiftData-Setup-frei,
(2) Die Hex-Architektur-Grenze (Domain ↔ Infrastruktur) ist im Package-Graph
sichtbar, nicht nur in Ordnerstruktur, (3) Package-`platforms` müssen auf
`.macOS(.v14)` hoch, weil SwiftData es so verlangt — Core-Code compiliert trotzdem
auf älteren macOS-Versionen, aber das Package wird konsumenten-seitig auf 14+
beschränkt (irrelevant: wir liefern nur iOS/tvOS-Apps). Alternative "alles in Core"
wurde verworfen, weil sie die Tests-Geschwindigkeit und die Layering-Klarheit
schlechter macht ohne nennenswerten Vorteil — das Sub-Target ist 15 Zeilen
zusätzliches `Package.swift`.
