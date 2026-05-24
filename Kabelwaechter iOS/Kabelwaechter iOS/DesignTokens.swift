import SwiftUI

/// Kabelwächter-Designsystem-Konstanten.
///
/// Quelle: `Design/Tokens/colors-extracted.md`. SwiftUI-`Color`-Konstanten
/// für Previews und schnellen Code-Zugriff. Parallel sollten die gleichen
/// Werte in `Assets.xcassets` als Named Colors landen (Light/Dark-Varianten,
/// Theme-fähig); diese Konstanten sind der Quellcode-Pfad, Catalog ist die
/// produktions-Variante. Bis Catalog-Migration: alle Views nutzen die
/// Konstanten direkt.
enum DesignTokens {

    // MARK: - Hintergründe (dunkel → hell)

    /// Tiefster Hintergrund — OLED-Black. App-Wide-Background.
    static let surfaceDeepest = Color(hex: 0x02040A)

    /// Sekundärer Hintergrund — z.B. Navigation-Hintergründe.
    static let surfaceSecondary = Color(hex: 0x0A0F1A)

    /// Karten-/Listenzeilen-Hintergrund.
    static let surfaceCard = Color(hex: 0x0F1F33)

    // MARK: - Akzente

    /// Primäre Akzentfarbe — Cyan/Electric Blue.
    /// Verwendung: aktive Buttons, Selection-States, Logo-Outline.
    static let accentPrimary = Color(hex: 0x00D4FF)

    /// Sekundäre Akzentfarbe — Mint-Grün.
    /// Verwendung: „Verbindung aktiv", Erfolgs-Indikatoren, Logo-Kern.
    static let accentSuccess = Color(hex: 0x00FF9D)

    // MARK: - Text / Vordergrund

    /// Primärer Vordergrund — Pale Blau-Weiß auf den Navy-Hintergründen.
    static let textPrimary = Color(hex: 0xE6F3FF)

    /// Gedämpfter Text — Secondary-Labels, Captions. Hergeleitet (70%).
    static let textSecondary = Color(hex: 0xE6F3FF).opacity(0.7)

    /// Tertiär — Hinweise, Trennungen.
    static let textTertiary = Color(hex: 0xE6F3FF).opacity(0.45)

    // MARK: - Gradients

    /// App-Background-Gradient: tiefstes Schwarz-Blau zu helleres Navy.
    static let backgroundGradient = LinearGradient(
        colors: [surfaceDeepest, surfaceSecondary, surfaceCard],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Typografie

    /// Brand-Font — Monospace, passend zum Wordmark.
    /// Fallback-Kette: explizite Monospace-Faces, dann System.
    static let brandFont = Font.system(.headline, design: .monospaced).weight(.bold)
}

// MARK: - Color(hex:) Helper

extension Color {
    /// Erzeugt eine Farbe aus einem 0xRRGGBB-Integer. Quick-Init für
    /// Designtoken-Konstanten — die Catalog-Migration ersetzt dies später.
    init(hex: Int, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}
