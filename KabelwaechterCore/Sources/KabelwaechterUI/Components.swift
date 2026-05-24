// ──────────────────────────────────────────────────────────────────────────
// Components.swift
// CyberBackdrop (Grund-Canvas: Radial-Glow + Grid + Vignette + Scanline)
// und KabelLogo. SwiftUI-Ports aus cyber-shared.jsx / v1-screens.jsx.
// ──────────────────────────────────────────────────────────────────────────

import SwiftUI

// MARK: - CyberBackdrop

/// Der Hintergrund jeder Vollbild-Fläche: tiefes Navy-Radial mit feinem
/// Cyan-Grid (zur Mitte hin sichtbar, zum Rand maskiert), Kanten-Vignette und
/// optionaler durchlaufender Scanline. Inhalt wird darüber gelegt.
public struct CyberBackdrop<Content: View>: View {
    public var accent: Color
    public var showScan: Bool
    private let content: Content

    public init(accent: Color = .kwCyan, showScan: Bool = true, @ViewBuilder content: () -> Content) {
        self.accent = accent
        self.showScan = showScan
        self.content = content()
    }

    @State private var scan = false

    public var body: some View {
        ZStack {
            // Radial-Grund
            RadialGradient(
                colors: [.kwBg2, .kwBg1, .kwBg0],
                center: UnitPoint(x: 0.5, y: 0.4),
                startRadius: 0, endRadius: 900
            )

            // Grid, zur Mitte hin sichtbar
            GridLayer()
                .mask(
                    RadialGradient(
                        colors: [.black, .black.opacity(0)],
                        center: .center, startRadius: 60, endRadius: 700
                    )
                )

            // Kanten-Vignette
            RadialGradient(
                colors: [.clear, .black.opacity(0.55)],
                center: .center, startRadius: 200, endRadius: 760
            )
            .allowsHitTesting(false)

            // Scanline
            if showScan {
                GeometryReader { geo in
                    LinearGradient(
                        colors: [.clear, accent.opacity(0.07), .clear],
                        startPoint: .top, endPoint: .bottom
                    )
                    .frame(height: 80)
                    .offset(y: scan ? geo.size.height : -80)
                    .onAppear {
                        withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                            scan = true
                        }
                    }
                }
                .allowsHitTesting(false)
            }

            content
        }
        .background(Color.kwBg0)
    }
}

/// Feines 40-pt-Cyan-Raster.
private struct GridLayer: View {
    var body: some View {
        Canvas { ctx, size in
            let step: CGFloat = 40
            var path = Path()
            var x: CGFloat = 0
            while x <= size.width { path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: size.height)); x += step }
            var y: CGFloat = 0
            while y <= size.height { path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: size.width, y: y)); y += step }
            ctx.stroke(path, with: .color(.kwGrid), lineWidth: 1)
        }
    }
}

// MARK: - KabelLogo

/// Die Wortmarke-Glyphe: rotiertes Quadrat mit Innenrahmen + Signal-Kern.
public struct KabelLogo: View {
    public var accent: Color
    public var size: CGFloat

    public init(accent: Color = .kwCyan, size: CGFloat = 28) {
        self.accent = accent
        self.size = size
    }

    public var body: some View {
        ZStack {
            Rectangle().stroke(accent, lineWidth: 1.5)
            Rectangle().stroke(accent.opacity(0.53), lineWidth: 1)
                .padding(size * 0.14)
            Circle().fill(accent)
                .frame(width: size * 0.14, height: size * 0.14)
                .shadow(color: accent, radius: 4)
        }
        .frame(width: size, height: size)
        .rotationEffect(.degrees(45))
    }
}
