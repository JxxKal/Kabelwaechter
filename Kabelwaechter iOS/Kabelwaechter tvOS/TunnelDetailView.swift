import SwiftUI
import NetworkExtension
import KabelwaechterCore
import KabelwaechterPersistence
import KabelwaechterUI

/// Detailansicht eines Tunnels auf tvOS im „Centered Hub"-Design (Variant A):
/// die Tunnel-Visualisierung füllt den Hintergrund, der aktive Peer + Status
/// stehen mittig, darunter der große Connect-Button.
struct TunnelDetailView: View {

    @Environment(TVAppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss

    let tunnelID: UUID

    @State private var tunnel: TunnelView?
    @State private var fullConfig: TunnelConfiguration?
    @State private var loadError: String?
    @State private var confirmingDelete = false
    @State private var connectError: String?
    @State private var stats: TunnelManager.TunnelStats?
    @State private var autoConnect = false

    var body: some View {
        let status = env.tunnelManager.status(forTunnelID: tunnelID) ?? .invalid
        let vizState = connectError != nil ? .error : Self.vizState(for: status)

        ZStack {
            CyberBackdrop(accent: .kwCyan) {
                TunnelViz(state: vizState, intensity: tunnel?.isConfiguredHere == true ? 1.0 : 0.5)
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar(status: status)
                Spacer()
                centerHUD(status: status, vizState: vizState)
                Spacer()
                bottomControls(status: status)
            }
            .padding(KW.Space.gutter)
            .padding(.vertical, KW.Space.safeTop)
        }
        .preferredColorScheme(.dark)
        .task { reload() }
        .task(id: status) { await pollStats(status: status) }
        .alert("Tunnel löschen?", isPresented: $confirmingDelete) {
            Button("Löschen", role: .destructive, action: deleteTunnel)
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Wird auf allen iCloud-Geräten entfernt.")
        }
    }

    // MARK: - Top bar

    private func topBar(status: NEVPNStatus) -> some View {
        HStack(alignment: .center) {
            HStack(spacing: KW.Space.md) {
                KabelLogo(size: 40)
                VStack(alignment: .leading, spacing: 4) {
                    Text("[ KABELWÄCHTER ]").kwLabel()
                    if let endpoint = tunnel?.serverEndpoint, !endpoint.isEmpty {
                        Text(endpoint)
                            .font(KW.Font.telemTV)
                            .foregroundStyle(Color.kwTextDim)
                    }
                }
            }
            Spacer()
            StatusPill(state: connectError != nil ? .error : Self.vizState(for: status))
        }
    }

    // MARK: - Center HUD

    @ViewBuilder
    private func centerHUD(status: NEVPNStatus, vizState: KWConnectionState) -> some View {
        if tunnel?.isConfiguredHere == false {
            syncingHUD
        } else {
            VStack(spacing: KW.Space.lg) {
                Text(kicker(for: vizState))
                    .font(KW.Font.labelTV)
                    .tracking(6)
                    .foregroundStyle(vizState.color)
                Text(tunnel?.name ?? "—")
                    .font(KW.Font.displayTV)
                    .foregroundStyle(Color.kwText)
                    .shadow(color: vizState == .connected ? Color.kwSignal.opacity(0.4) : .clear, radius: KW.Glow.textShadow)
                    .multilineTextAlignment(.center)
                if let peer = fullConfig?.peers.first?.endpoint?.stringRepresentation {
                    Text(peer.uppercased() + " · :51820")
                        .font(KW.Font.telemTV)
                        .tracking(2)
                        .foregroundStyle(Color.kwTextDim)
                }
                if let stats { telemetry(stats) }
            }
        }
    }

    private func telemetry(_ s: TunnelManager.TunnelStats) -> some View {
        HStack(spacing: KW.Space.xl) {
            telemItem(symbol: "arrow.up", value: Self.fmtBytes(s.txBytes), tint: .kwCyan)
            telemItem(symbol: "arrow.down", value: Self.fmtBytes(s.rxBytes), tint: .kwSignal)
            telemItem(symbol: "arrow.triangle.2.circlepath",
                      value: s.lastHandshake.map(Self.relHandshake) ?? "—",
                      tint: .kwTextDim)
        }
        .padding(.top, KW.Space.sm)
    }

    private func telemItem(symbol: String, value: String, tint: Color) -> some View {
        HStack(spacing: KW.Space.xs) {
            Image(systemName: symbol).foregroundStyle(tint)
            Text(value).foregroundStyle(Color.kwText)
        }
        .font(KW.Font.telemTV)
    }

    private var syncingHUD: some View {
        VStack(spacing: KW.Space.md) {
            Text("[ iCLOUD-SYNC LÄUFT ]").kwLabel()
            Text(tunnel?.name ?? "—")
                .font(KW.Font.titleTV)
                .foregroundStyle(Color.kwText)
            Text("Die vollständige Konfiguration ist noch nicht angekommen. Verbinden wird aktiv, sobald der Sync durch ist.")
                .font(KW.Font.bodyTV)
                .foregroundStyle(Color.kwTextDim)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 900)
        }
    }

    // MARK: - Bottom controls

    private func bottomControls(status: NEVPNStatus) -> some View {
        let configured = tunnel?.isConfiguredHere == true
        return VStack(spacing: KW.Space.md) {
            if let connectError {
                Text(connectError)
                    .font(KW.Font.telemTV)
                    .foregroundStyle(Color.kwError)
                    .lineLimit(2)
            }
            HStack(spacing: KW.Space.lg) {
                Button {
                    Task { await toggleConnection(currentStatus: status) }
                } label: {
                    Text(connectLabel(for: status))
                }
                .buttonStyle(KWButtonStyle(
                    tone: status == .connected ? .kwSignal : .kwCyan,
                    filled: status == .disconnected || status == .invalid
                ))
                .disabled(!configured || status == .connecting || status == .disconnecting)
                .frame(maxWidth: .infinity)

                Button {
                    Task { await toggleAutoConnect() }
                } label: {
                    Text(autoConnect ? "Auto-Connect: An" : "Auto-Connect: Aus")
                }
                .buttonStyle(KWButtonStyle(tone: autoConnect ? .kwSignal : .kwTextDim))
                .disabled(!configured)
                .frame(width: 460)
            }

            Button(role: .destructive) {
                confirmingDelete = true
            } label: {
                Text("Löschen")
            }
            .buttonStyle(KWButtonStyle(tone: .kwError))
            .frame(width: 280)
        }
    }

    // MARK: - Logic

    private func toggleConnection(currentStatus: NEVPNStatus) async {
        connectError = nil
        switch currentStatus {
        case .connected, .connecting, .reasserting:
            await env.tunnelManager.disconnect(tunnelID: tunnelID)
        case .disconnected, .disconnecting, .invalid:
            fallthrough
        @unknown default:
            do {
                try await env.tunnelManager.connect(tunnelID: tunnelID, displayName: tunnel?.name ?? "Kabelwächter")
            } catch {
                connectError = String(describing: error)
            }
        }
        autoConnect = env.tunnelManager.isAutoConnect(tunnelID: tunnelID)
    }

    private func toggleAutoConnect() async {
        connectError = nil
        do {
            try await env.tunnelManager.setAutoConnect(
                !autoConnect,
                tunnelID: tunnelID,
                displayName: tunnel?.name ?? "Kabelwächter"
            )
        } catch {
            connectError = String(describing: error)
        }
        autoConnect = env.tunnelManager.isAutoConnect(tunnelID: tunnelID)
    }

    private func connectLabel(for status: NEVPNStatus) -> String {
        switch status {
        case .connected:                 return "× Trennen"
        case .connecting:                return "Verbindet…"
        case .disconnecting:             return "Trennt…"
        case .reasserting:               return "Reconnect…"
        case .disconnected, .invalid:    return "▶ Verbinden"
        @unknown default:                return "▶ Verbinden"
        }
    }

    private func kicker(for state: KWConnectionState) -> String {
        switch state {
        case .connected:  return "ACTIVE PEER"
        case .connecting: return "HANDSHAKE…"
        case .error:      return "PEER UNREACHABLE"
        case .idle:       return "STANDBY"
        }
    }

    private static func vizState(for status: NEVPNStatus) -> KWConnectionState {
        switch status {
        case .connected:               return .connected
        case .connecting, .reasserting: return .connecting
        default:                       return .idle
        }
    }

    /// Pollt die Live-Stats alle 2s, solange der Tunnel verbunden ist.
    /// Läuft via `.task(id: status)` neu an, wenn sich der Status ändert.
    private func pollStats(status: NEVPNStatus) async {
        guard status == .connected else { stats = nil; return }
        while !Task.isCancelled {
            stats = await env.tunnelManager.fetchStats(tunnelID: tunnelID)
            try? await Task.sleep(for: .seconds(2))
        }
    }

    private static func fmtBytes(_ b: UInt64) -> String {
        let f = ByteCountFormatter()
        f.countStyle = .binary
        return f.string(fromByteCount: Int64(min(b, UInt64(Int64.max))))
    }

    private static func relHandshake(_ d: Date) -> String {
        let s = max(0, Int(Date().timeIntervalSince(d)))
        if s < 60 { return "vor \(s)s" }
        if s < 3600 { return "vor \(s / 60)m" }
        return "vor \(s / 3600)h"
    }

    private func reload() {
        do {
            tunnel = try env.repository.tunnel(id: tunnelID)
            fullConfig = try? env.repository.tunnelConfiguration(id: tunnelID)
            autoConnect = env.tunnelManager.isAutoConnect(tunnelID: tunnelID)
            loadError = nil
        } catch {
            loadError = String(describing: error)
        }
    }

    private func deleteTunnel() {
        try? env.repository.deleteTunnel(id: tunnelID)
        dismiss()
    }
}

#Preview {
    TunnelDetailView(tunnelID: UUID())
        .environment(TVAppEnvironment.makePreview())
}
