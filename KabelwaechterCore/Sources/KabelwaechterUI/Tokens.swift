// ──────────────────────────────────────────────────────────────────────────
// Tokens.swift
// Kabelwächter — Design Tokens for iOS + tvOS
//
// Single source of truth for color, type, spacing, radii, and motion.
// Mirrors the values defined in "Kabelwächter — Brand Guide.html".
//
// Usage:
//   .foregroundStyle(Color.kwCyan)
//   .font(KW.Font.title)
//   .padding(KW.Space.lg)
// ──────────────────────────────────────────────────────────────────────────

import SwiftUI

// MARK: - Namespace

public enum KW {
    public enum Space {}
    public enum Radius {}
    public enum Border {}
    public enum Motion {}
    public enum Glow {}
    public enum Font {}
}

// MARK: - Colors
//
// Colors are exposed two ways:
//   1. As SwiftUI Color literals on `Color` (works from any module, no asset
//      catalog lookup, ideal for previews and tests).
//   2. As named colors in `Colors.xcassets` (`kw/cyan`, `kw/bg0`, …) so
//      designers can tweak them without recompiling — see the Asset Catalog
//      shipped alongside this file.

public extension Color {

    // Surfaces — deep navy, never pure black
    static let kwBg0 = Color(hex: 0x05080D)              // deepest backdrop
    static let kwBg1 = Color(hex: 0x0A0F1A)              // surface
    static let kwBg2 = Color(hex: 0x0F1825)              // raised
    static let kwBg3 = Color(hex: 0x152135)              // selected / focus fill

    // Signal — single-use semantic colors
    static let kwCyan   = Color(hex: 0x00D4FF)           // primary accent
    static let kwCyanSoft = Color(hex: 0x5BE0FF)         // hover / focus
    static let kwSignal = Color(hex: 0x00FF9D)           // "connected" — RESERVED
    static let kwWarn   = Color(hex: 0xFFB84D)           // handshake / warning
    static let kwError  = Color(hex: 0xFF4757)           // error / disconnect

    // Text
    static let kwText      = Color(hex: 0xE6F3FF)
    static let kwTextDim   = Color(hex: 0xE6F3FF, opacity: 0.55)
    static let kwTextFaint = Color(hex: 0xE6F3FF, opacity: 0.32)

    // Lines & grid
    static let kwLine    = Color(hex: 0x00D4FF, opacity: 0.35)
    static let kwLineDim = Color(hex: 0x00D4FF, opacity: 0.15)
    static let kwGrid    = Color(hex: 0x00D4FF, opacity: 0.08)
}

// MARK: - Connection state → color helper

public enum KWConnectionState {
    case idle, connecting, connected, error

    public var color: Color {
        switch self {
        case .idle:       return .kwTextFaint
        case .connecting: return .kwWarn
        case .connected:  return .kwSignal
        case .error:      return .kwError
        }
    }

    public var label: String {
        switch self {
        case .idle:       return "STANDBY"
        case .connecting: return "HANDSHAKE…"
        case .connected:  return "TUNNEL UP"
        case .error:      return "PEER UNREACHABLE"
        }
    }
}

// MARK: - Typography
//
// SF Mono is the brand voice. It ships with every Apple OS — no font files.
// Use `.kwBody` (SF Pro Text) only for long-form prose where mono would tire
// the eye.

public extension KW.Font {

    // — iOS / shared ramp
    static let display = SwiftUI.Font.system(size: 56, weight: .bold,    design: .monospaced)
    static let title   = SwiftUI.Font.system(size: 32, weight: .bold,    design: .monospaced)
    static let h2      = SwiftUI.Font.system(size: 22, weight: .medium,  design: .monospaced)
    static let label   = SwiftUI.Font.system(size: 11, weight: .medium,  design: .monospaced)
    static let telem   = SwiftUI.Font.system(size: 13, weight: .regular, design: .monospaced)
    static let body    = SwiftUI.Font.system(size: 15, weight: .regular)
    static let bodySm  = SwiftUI.Font.system(size: 13, weight: .regular)

    // — tvOS ramp (sofa distance, ~2.2× scale)
    static let displayTV = SwiftUI.Font.system(size: 124, weight: .bold,    design: .monospaced)
    static let titleTV   = SwiftUI.Font.system(size: 76,  weight: .bold,    design: .monospaced)
    static let h2TV      = SwiftUI.Font.system(size: 48,  weight: .medium,  design: .monospaced)
    static let labelTV   = SwiftUI.Font.system(size: 24,  weight: .medium,  design: .monospaced)
    static let telemTV   = SwiftUI.Font.system(size: 28,  weight: .regular, design: .monospaced)
    static let bodyTV    = SwiftUI.Font.system(size: 32,  weight: .regular)

    // — Adaptive accessors. Use these from cross-platform code.
    static var titleAdaptive: SwiftUI.Font {
        #if os(tvOS)
        return titleTV
        #else
        return title
        #endif
    }
    static var labelAdaptive: SwiftUI.Font {
        #if os(tvOS)
        return labelTV
        #else
        return label
        #endif
    }
    static var bodyAdaptive: SwiftUI.Font {
        #if os(tvOS)
        return bodyTV
        #else
        return body
        #endif
    }
}

// MARK: - Spacing
//
// 8-pt grid with 4-pt subdivisions. Use these names — don't hardcode pixel
// values in views.

public extension KW.Space {
    static let xxs: CGFloat = 4
    static let xs:  CGFloat = 8
    static let sm:  CGFloat = 12
    static let md:  CGFloat = 16
    static let lg:  CGFloat = 24
    static let xl:  CGFloat = 32
    static let xxl: CGFloat = 48
    static let page: CGFloat = 40    // page rhythm

    // tvOS uses bigger gutters
    #if os(tvOS)
    static let gutter: CGFloat = 56
    static let safeTop: CGFloat = 60
    #else
    static let gutter: CGFloat = 24
    static let safeTop: CGFloat = 16
    #endif
}

// MARK: - Radii & Borders
//
// Hard edges — squared corners read as instrumentation.

public extension KW.Radius {
    static let none: CGFloat = 0
    static let xs:   CGFloat = 2
    static let sm:   CGFloat = 6
    // Anything larger is OFF-BRAND. Use corner brackets instead.
}

public extension KW.Border {
    static let hairline: CGFloat = 1
    static let bracket:  CGFloat = 1.5
}

// MARK: - Motion

public extension KW.Motion {
    static let blink   = Animation.easeInOut(duration: 1.4).repeatForever(autoreverses: true)
    static let pulse   = Animation.easeInOut(duration: 2.0).repeatForever(autoreverses: true)
    static let scan    = Animation.linear(duration: 3.5).repeatForever(autoreverses: false)
    static let snap    = Animation.spring(response: 0.32, dampingFraction: 0.78)
    static let connect = Animation.easeOut(duration: 1.1)
}

// MARK: - Glow (used on focused / connected elements)

public extension KW.Glow {
    static let focus      : CGFloat = 12  // tvOS focus ring blur
    static let signal     : CGFloat = 18  // connected button shadow
    static let textShadow : CGFloat = 24  // hero accent shadow
}

// MARK: - Color hex helper

public extension Color {
    init(hex: UInt, opacity: Double = 1.0) {
        self.init(
            .sRGB,
            red:   Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8)  & 0xFF) / 255,
            blue:  Double( hex        & 0xFF) / 255,
            opacity: opacity
        )
    }
}
