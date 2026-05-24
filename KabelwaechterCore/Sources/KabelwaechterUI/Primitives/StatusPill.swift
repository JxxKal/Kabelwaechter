// ──────────────────────────────────────────────────────────────────────────
// StatusPill.swift
// The connection-state chip used across both platforms.
// Anatomy: 3/9 px padding, 1 px border, 2 px radius, 5 px dot,
// uppercase mono, +0.10em tracking.
// ──────────────────────────────────────────────────────────────────────────

import SwiftUI

public struct StatusPill: View {
    public let state: KWConnectionState
    public let label: String
    public var animated: Bool = true

    @State private var blip = false

    public init(state: KWConnectionState, label: String? = nil, animated: Bool = true) {
        self.state = state
        self.label = label ?? state.label
        self.animated = animated
    }

    public var body: some View {
        HStack(spacing: KW.Space.xxs + 2) {
            Circle()
                .fill(state.color)
                .frame(width: 5, height: 5)
                .shadow(color: state.color, radius: 4)
                .opacity(animated && state == .connecting ? (blip ? 1.0 : 0.35) : 1.0)
                .onAppear {
                    guard animated else { return }
                    withAnimation(KW.Motion.blink) { blip.toggle() }
                }

            Text(label)
                .font(KW.Font.label)
                .tracking(1.1)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 3)
        .foregroundStyle(state.color)
        .background(state.color.opacity(0.10))
        .overlay(
            Rectangle().stroke(state.color.opacity(0.45), lineWidth: KW.Border.hairline)
        )
        .cornerRadius(KW.Radius.xs)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        StatusPill(state: .connected)
        StatusPill(state: .connecting)
        StatusPill(state: .error)
        StatusPill(state: .idle, label: "STANDBY")
    }
    .padding(32)
    .background(Color.kwBg0)
}
