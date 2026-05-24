# Color Tokens (extrahiert aus SVGs)

Stand: 2026-05-18. Automatisch aus den vorliegenden SVG-Quelldateien
(`Design/Assets/`, `Design/AppIcons/iOS/`) extrahiert. **Bitte verifizieren
und um fehlende Tokens ergänzen**, bevor wir daraus `DesignTokens.swift` in
`KabelwaechterCore` generieren.

## Gefundene Farben

| Hex | Visuell | Vermutete Rolle |
|---|---|---|
| `#02040a` | tiefes Schwarz-Blau | tiefster Hintergrund / OLED-Black |
| `#0a0f1a` | dunkles Navy | Sekundär-Hintergrund |
| `#0f1f33` | helleres Navy | Tertiär-Hintergrund / Karten |
| `#00d4ff` | Cyan / Electric Blue | Primäre Akzentfarbe |
| `#00ff9d` | Mint-Grün | Sekundäre Akzentfarbe (z.B. „Verbindung aktiv") |
| `#e6f3ff` | Pale Blau-Weiß | Primärer Vordergrund / Text |

Gefunden in:
- `logo-mark.svg` — Grün-Cyan-Gradient zum Mark-Kern
- `icon-1024.svg` — Background-Gradient navy-dark, Akzent-Highlights
- `lockup-horizontal.svg`, `wordmark.svg` — Foreground-Text + Akzente

## Fehlt vermutlich noch

- **Warning / Error** (Rot oder Orange für Fehlerzustände, ungültige Configs)
- **Neutral-Grays** für Disabled-States, Trennlinien
- **Light-Mode-Varianten** falls iOS-Companion Light Mode supporten soll
- **System-Color-Bridges** (z.B. ob `e6f3ff` immer als Text dient oder
  systemPrimary mappen soll)

## Migrations-Plan nach Phase 1 / 4

Wenn das Xcode-Projekt steht (Phase-1-Schritt 4):

1. Diese Tokens werden in `KabelwaechterCore/Sources/KabelwaechterCore/DesignTokens.swift`
   als `Color`-Konstanten kodiert
2. Parallel werden sie als **Named Colors in `Assets.xcassets`** angelegt
   (Light/Dark/Any-Variants), referenziert via `Color("...", bundle: .module)`
3. Vorteil dieser doppelten Speicherung: SwiftUI-Previews funktionieren ohne
   Color-Catalog (Konstanten), Production zieht aus Catalog (Theme-fähig)
