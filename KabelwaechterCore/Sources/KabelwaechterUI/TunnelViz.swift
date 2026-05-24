// ──────────────────────────────────────────────────────────────────────────
// TunnelViz.swift
// Die perspektivische Tunnel-Visualisierung — Herzstück der Designsprache.
// SwiftUI-Port der `TunnelViz`-Komponente aus dem React-Hi-Fi-Mockup
// (cyber-shared.jsx). Gezeichnet mit Canvas + TimelineView, damit auf tvOS
// nur ein einziger Render-Loop läuft statt N Einzel-Animationen.
// ──────────────────────────────────────────────────────────────────────────

import SwiftUI

public enum TunnelVizVariant: String, CaseIterable, Sendable {
    case rings, grid, particles
}

public struct TunnelViz: View {
    public var variant: TunnelVizVariant
    public var state: KWConnectionState
    public var accent: Color
    /// 0…1 — globale Deckkraft/Dichte (für gedämpfte Hintergrund-Instanzen).
    public var intensity: Double

    public init(
        variant: TunnelVizVariant = .rings,
        state: KWConnectionState = .connected,
        accent: Color = .kwCyan,
        intensity: Double = 1.0
    ) {
        self.variant = variant
        self.state = state
        self.accent = accent
        self.intensity = intensity
    }

    private static let ringCount = 9

    /// Ausbreitungsgeschwindigkeit der Ringe — schneller wenn verbunden,
    /// nervös beim Handshake, fast still im Leerlauf.
    private var speed: Double {
        switch state {
        case .connecting: return 0.42
        case .connected:  return 0.62
        case .error:      return 0.16
        case .idle:       return 0.14
        }
    }

    private var ringColor: Color {
        switch state {
        case .error:     return .kwError
        case .connected: return .kwSignal
        default:         return accent
        }
    }

    public var body: some View {
        // 30 fps statt 60 — auf älterer Apple-TV-Hardware (A8) reicht das
        // visuell und lässt dem UI-Thread (Focus-Engine!) Luft.
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let maxR = min(size.width, size.height) * 0.62

                drawCoreGlow(in: &ctx, center: center, maxR: maxR)
                if variant != .particles {
                    drawRays(in: &ctx, center: center, reach: max(size.width, size.height))
                }
                switch variant {
                case .rings:     drawRings(in: &ctx, center: center, maxR: maxR, t: t)
                case .grid:      drawGrid(in: &ctx, center: center, maxR: maxR, t: t)
                case .particles: drawParticles(in: &ctx, center: center, maxR: maxR, t: t)
                }
                drawReticle(in: &ctx, center: center)
            }
        }
        .allowsHitTesting(false) // rein dekorativ — nie Eingaben abfangen
    }

    // MARK: - Layers

    private func drawCoreGlow(in ctx: inout GraphicsContext, center: CGPoint, maxR: CGFloat) {
        let r = maxR * 0.8
        let rect = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
        let gradient = Gradient(stops: [
            .init(color: ringColor.opacity(0.55 * intensity), location: 0),
            .init(color: ringColor.opacity(0.12 * intensity), location: 0.4),
            .init(color: ringColor.opacity(0), location: 1),
        ])
        ctx.fill(
            Path(ellipseIn: rect),
            with: .radialGradient(gradient, center: center, startRadius: 0, endRadius: r)
        )
    }

    private func drawRays(in ctx: inout GraphicsContext, center: CGPoint, reach: CGFloat) {
        let count = 10
        for i in 0..<count {
            let a = CGFloat(i) / CGFloat(count) * 2 * .pi
            var p = Path()
            p.move(to: center)
            p.addLine(to: CGPoint(x: center.x + cos(a) * reach, y: center.y + sin(a) * reach))
            ctx.stroke(p, with: .color(accent.opacity(0.18 * intensity)), lineWidth: 0.5)
        }
    }

    /// Phase eines Rings: 0…1, wandert mit der Zeit nach außen.
    private func ringPhase(_ i: Int, _ t: Double) -> Double {
        let base = (t * speed + Double(i) / Double(Self.ringCount))
        return base - floor(base)
    }

    private func drawRings(in ctx: inout GraphicsContext, center: CGPoint, maxR: CGFloat, t: Double) {
        for i in 0..<Self.ringCount {
            let phase = ringPhase(i, t)
            let radius = maxR * CGFloat(0.08 + phase)
            let opacity = fadeOpacity(phase) * intensity * (state == .error ? 0.7 : 1)
            guard opacity > 0.01 else { continue }
            let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
            let lineWidth: CGFloat = phase < 0.25 ? 1.6 : 0.9
            var style = StrokeStyle(lineWidth: lineWidth)
            if state == .connecting && phase < 0.5 { style.dash = [6, 4] }
            ctx.stroke(Path(ellipseIn: rect), with: .color(ringColor.opacity(opacity)), style: style)
        }
    }

    private func drawGrid(in ctx: inout GraphicsContext, center: CGPoint, maxR: CGFloat, t: Double) {
        let sides = 6
        for i in 0..<Self.ringCount {
            let phase = ringPhase(i, t)
            let radius = maxR * CGFloat(0.08 + phase)
            let opacity = fadeOpacity(phase) * intensity * (state == .error ? 0.7 : 1)
            guard opacity > 0.01 else { continue }
            var p = Path()
            for k in 0...sides {
                let a = CGFloat(k) / CGFloat(sides) * 2 * .pi - .pi / 2
                let pt = CGPoint(x: center.x + cos(a) * radius, y: center.y + sin(a) * radius)
                if k == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
            }
            ctx.stroke(p, with: .color(ringColor.opacity(opacity)), lineWidth: phase < 0.25 ? 1.4 : 0.8)
        }
    }

    private func drawParticles(in ctx: inout GraphicsContext, center: CGPoint, maxR: CGFloat, t: Double) {
        let count = 64
        for i in 0..<count {
            let ang = CGFloat(i) * 137.5 * .pi / 180
            // Partikel fließen nach innen: Radius schrumpft zyklisch.
            let seed = Double((i * 73) % 100) / 100
            let prog = (t * speed * 1.4 + seed).truncatingRemainder(dividingBy: 1)
            let radius = maxR * CGFloat(1 - prog)
            let opacity = (1 - prog) * intensity * 0.9 * (state == .error ? 0.7 : 1)
            guard opacity > 0.02 else { continue }
            let pt = CGPoint(x: center.x + cos(ang) * radius, y: center.y + sin(ang) * radius)
            let dotR: CGFloat = 1.8
            ctx.fill(
                Path(ellipseIn: CGRect(x: pt.x - dotR, y: pt.y - dotR, width: dotR * 2, height: dotR * 2)),
                with: .color(ringColor.opacity(opacity))
            )
        }
    }

    private func drawReticle(in ctx: inout GraphicsContext, center: CGPoint) {
        let outer: CGFloat = 6
        ctx.fill(
            Path(ellipseIn: CGRect(x: center.x - outer, y: center.y - outer, width: outer * 2, height: outer * 2)),
            with: .color(ringColor.opacity(state == .error ? 0.7 : 1))
        )
        let inner: CGFloat = 2
        ctx.fill(
            Path(ellipseIn: CGRect(x: center.x - inner, y: center.y - inner, width: inner * 2, height: inner * 2)),
            with: .color(.kwText)
        )
    }

    /// Ringe blenden am Anfang schnell ein und zum Rand hin aus.
    private func fadeOpacity(_ phase: Double) -> Double {
        let fadeIn = min(phase / 0.15, 1)
        let fadeOut = 1 - max((phase - 0.6) / 0.4, 0)
        return max(0, fadeIn * fadeOut)
    }
}

#if DEBUG
#Preview {
    HStack(spacing: 0) {
        ForEach(TunnelVizVariant.allCases, id: \.self) { v in
            ZStack {
                Color.kwBg0
                TunnelViz(variant: v, state: .connected)
            }
        }
    }
    .ignoresSafeArea()
}
#endif
