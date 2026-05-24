// ──────────────────────────────────────────────────────────────────────────
// Modifiers.swift
// View modifiers that encode brand recipes once, applied everywhere.
// ──────────────────────────────────────────────────────────────────────────

import SwiftUI

// MARK: - .kwLabel()
//
// Uppercase mono with +0.22em tracking, cyan tint. Used for kickers,
// status captions, "[ SECTION ]" headings.

public struct KWLabelStyle: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .font(KW.Font.labelAdaptive)
            .tracking(2.2)
            .textCase(.uppercase)
            .foregroundStyle(Color.kwCyan)
    }
}

public extension View {
    func kwLabel() -> some View { modifier(KWLabelStyle()) }
}

// MARK: - .kwPanel()
//
// Translucent navy surface with hairline cyan border. The base container
// for any grouped content.

public struct KWPanel: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .padding(KW.Space.lg)
            .background(
                LinearGradient(
                    colors: [Color.kwBg2.opacity(0.7), Color.kwBg1.opacity(0.7)],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .overlay(
                Rectangle().stroke(Color.kwLineDim, lineWidth: KW.Border.hairline)
            )
    }
}

public extension View {
    func kwPanel() -> some View { modifier(KWPanel()) }
}

// MARK: - .kwFocusRing(isFocused:)
//
// The tvOS focus indicator. Cyan outline + outer glow when focused.
// On iOS this collapses to nothing — wire it to `@FocusState` regardless.

public struct KWFocusRing: ViewModifier {
    let isFocused: Bool

    public func body(content: Content) -> some View {
        content
            .overlay(
                Rectangle()
                    .stroke(Color.kwCyan, lineWidth: isFocused ? 2 : 0)
            )
            .shadow(
                color: isFocused ? Color.kwCyan.opacity(0.6) : .clear,
                radius: isFocused ? KW.Glow.focus : 0
            )
            .scaleEffect(isFocused ? 1.04 : 1.0)
            .animation(KW.Motion.snap, value: isFocused)
    }
}

public extension View {
    func kwFocusRing(_ isFocused: Bool) -> some View {
        modifier(KWFocusRing(isFocused: isFocused))
    }
}
