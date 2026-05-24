// ──────────────────────────────────────────────────────────────────────────
// ButtonStyles.swift
// Marken-Button: harte Kanten, Hairline-Border, Mono-Caps. Auf tvOS reagiert
// er auf die Focus-Engine (Glow + leichte Skalierung), auf iOS auf Press.
// ──────────────────────────────────────────────────────────────────────────

import SwiftUI

public struct KWButtonStyle: ButtonStyle {
    public var tone: Color
    public var filled: Bool

    public init(tone: Color = .kwCyan, filled: Bool = false) {
        self.tone = tone
        self.filled = filled
    }

    public func makeBody(configuration: Configuration) -> some View {
        Content(configuration: configuration, tone: tone, filled: filled)
    }

    private struct Content: View {
        let configuration: ButtonStyleConfiguration
        let tone: Color
        let filled: Bool
        @Environment(\.isFocused) private var isFocused

        var body: some View {
            let active = isFocused || configuration.isPressed
            configuration.label
                .font(KW.Font.labelAdaptive)
                .tracking(2.0)
                .textCase(.uppercase)
                .foregroundStyle(filled ? Color.kwBg0 : tone)
                .padding(.vertical, KW.Space.md)
                .padding(.horizontal, KW.Space.xl)
                .frame(maxWidth: .infinity)
                .background(filled ? tone : tone.opacity(active ? 0.16 : 0.06))
                .overlay(Rectangle().stroke(tone, lineWidth: active ? 2 : KW.Border.hairline))
                .shadow(color: active ? tone.opacity(0.6) : .clear, radius: active ? KW.Glow.signal : 0)
                .scaleEffect(active ? 1.03 : 1.0)
                .animation(KW.Motion.snap, value: active)
        }
    }
}

// MARK: - KWCardButtonStyle
//
// Fokussierbare „Selected-Surface"-Card: Navy-Panel mit Hairline; bei Fokus
// Akzent-Border + Corner-Brackets + Glow + leichte Skalierung. Für die
// Tunnel-Cards im Hub.

public struct KWCardButtonStyle: ButtonStyle {
    public var accent: Color
    public var highlighted: Bool

    public init(accent: Color = .kwCyan, highlighted: Bool = false) {
        self.accent = accent
        self.highlighted = highlighted
    }

    public func makeBody(configuration: Configuration) -> some View {
        Content(configuration: configuration, accent: accent, highlighted: highlighted)
    }

    private struct Content: View {
        let configuration: ButtonStyleConfiguration
        let accent: Color
        let highlighted: Bool
        @Environment(\.isFocused) private var isFocused

        var body: some View {
            let active = isFocused || configuration.isPressed
            let showAccent = active || highlighted
            configuration.label
                .padding(KW.Space.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(showAccent ? accent.opacity(0.12) : Color.kwBg2.opacity(0.7))
                .overlay(Rectangle().stroke(showAccent ? accent : Color.kwLineDim, lineWidth: KW.Border.hairline))
                .overlay { if showAccent { CornerFrame(color: accent, size: 12, inset: -1) } }
                .shadow(color: active ? accent.opacity(0.5) : .clear, radius: active ? KW.Glow.focus : 0)
                .scaleEffect(active ? 1.04 : 1.0)
                .animation(KW.Motion.snap, value: active)
        }
    }
}
