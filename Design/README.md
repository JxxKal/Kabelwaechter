# Design Assets

Source-Ordner für alle Design-Quelldateien. Diese landen später in den
plattform-spezifischen `Assets.xcassets`-Bundles, sobald das Xcode-Projekt
existiert.

## Struktur

| Pfad | Inhalt |
|---|---|
| `Assets/` | Allgemeine Bilder (PNG, SVG, PDF) — Illustrations, In-App-Grafiken |
| `AppIcons/iOS/` | iOS-App-Icon-Quelle. Empfohlen: ein `Icon-1024.png` mit 1024×1024 px. Xcode 14+ generiert alle Größen automatisch daraus. |
| `AppIcons/tvOS/` | tvOS-App-Icon-Quellen: drei Layer (`Back.png`, `Middle.png`, `Front.png`) mit je 1920×1080 px für den Parallax-Effekt. Optional: `TopShelf.png` 1920×720 px und Brand Asset. |
| `Tokens/` | Farb-/Schrift-/Spacing-Tokens als Text (Markdown, JSON, CSV) — Quelle für die spätere Swift-Code-Generation in `KabelwaechterCore/DesignTokens.swift`. |

## Migration nach Xcode

Wenn das Xcode-Projekt steht (Phase-1-Schritt 4), wandern die Dateien wie folgt:

- `Assets/` → `KabelwaechteriOS/Assets.xcassets/` bzw. `KabelwaechtertvOS/Assets.xcassets/` (je nach Verwendung)
- `AppIcons/iOS/Icon-1024.png` → `KabelwaechteriOS/Assets.xcassets/AppIcon.appiconset/`
- `AppIcons/tvOS/*` → `KabelwaechtertvOS/Assets.xcassets/App Icon & Top Shelf Image.brandassets/`
- `Tokens/*` → manuelle Transkription in `KabelwaechterCore/Sources/KabelwaechterCore/DesignTokens.swift`

Quelldateien bleiben in `Design/` als Source of Truth.
