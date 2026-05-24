import SwiftUI

/// Kabelwächter-Designsystem für tvOS. Identisch zu iOS in den Farb-Tokens,
/// größere Schriften und Hit-Targets für 10-foot-UI. Quelle:
/// `Design/Tokens/colors-extracted.md`.
enum DesignTokens {

    // MARK: - Hintergründe

    static let surfaceDeepest = Color(hex: 0x02040A)
    static let surfaceSecondary = Color(hex: 0x0A0F1A)
    static let surfaceCard = Color(hex: 0x0F1F33)

    // MARK: - Akzente

    static let accentPrimary = Color(hex: 0x00D4FF)
    static let accentSuccess = Color(hex: 0x00FF9D)

    // MARK: - Text

    static let textPrimary = Color(hex: 0xE6F3FF)
    static let textSecondary = Color(hex: 0xE6F3FF).opacity(0.7)
    static let textTertiary = Color(hex: 0xE6F3FF).opacity(0.45)

    // MARK: - Gradients

    static let backgroundGradient = LinearGradient(
        colors: [surfaceDeepest, surfaceSecondary, surfaceCard],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Typografie (tvOS-gerecht groß)

    /// Brand-Font für tvOS — größer als iOS, weil Couch-Distanz.
    static let brandFont = Font.system(.title2, design: .monospaced).weight(.bold)
}

extension Color {
    init(hex: Int, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}
