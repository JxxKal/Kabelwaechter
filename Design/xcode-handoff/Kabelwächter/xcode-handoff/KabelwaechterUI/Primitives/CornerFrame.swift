// ──────────────────────────────────────────────────────────────────────────
// CornerFrame.swift
// The four cyan corner brackets that anchor "selected" surfaces.
// ──────────────────────────────────────────────────────────────────────────

import SwiftUI

public struct CornerFrame: View {
    public var color: Color = .kwCyan
    public var size: CGFloat = 12
    public var thickness: CGFloat = KW.Border.bracket
    public var inset: CGFloat = -1
    public var animate: Bool = false

    @State private var pulse = false

    public init(
        color: Color = .kwCyan,
        size: CGFloat = 12,
        thickness: CGFloat = KW.Border.bracket,
        inset: CGFloat = -1,
        animate: Bool = false
    ) {
        self.color = color
        self.size = size
        self.thickness = thickness
        self.inset = inset
        self.animate = animate
    }

    public var body: some View {
        GeometryReader { _ in
            ZStack {
                corner(.topLeading)
                corner(.topTrailing)
                corner(.bottomLeading)
                corner(.bottomTrailing)
            }
            .padding(inset)
            .opacity(animate ? (pulse ? 1.0 : 0.4) : 1.0)
            .onAppear {
                guard animate else { return }
                withAnimation(KW.Motion.blink) { pulse.toggle() }
            }
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func corner(_ alignment: Alignment) -> some View {
        // Two strokes per corner: one horizontal, one vertical.
        ZStack(alignment: alignment) {
            Color.clear
            Rectangle()
                .fill(color)
                .frame(width: size, height: thickness)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
            Rectangle()
                .fill(color)
                .frame(width: thickness, height: size)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
        }
    }
}
