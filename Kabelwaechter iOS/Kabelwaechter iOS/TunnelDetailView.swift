import SwiftUI
import NetworkExtension
import KabelwaechterCore
import KabelwaechterPersistence
import KabelwaechterUI

/// Detailansicht eines Tunnels im Kabelwächter-Design. Zeigt Config, erlaubt
/// Bearbeiten/Verschieben/Löschen — und seit der iOS-NE verbindet das iPhone
/// `phone`-Tunnel auch selbst (Decision #8 revidiert). `appleTV`-Tunnel werden
/// hier nicht verbunden (die baut die Apple TV auf).
struct TunnelDetailView: View {

    @Environment(CompanionAppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss

    let tunnelID: UUID

    @State private var tunnel: TunnelView?
    @State private var fullConfig: TunnelConfiguration?
    @State private var loadError: String?
    @State private var confirmingDelete = false
    @State private var showEdit = false
    @State private var connectError: String?
    @State private var autoConnect = false
    @State private var stats: TunnelManager.TunnelStats?

    var body: some View {
        ZStack {
            Color.kwBg0.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: KW.Space.lg) {
                    header
                    if tunnel?.target == .phone, tunnel?.isConfiguredHere == true {
                        connectControl
                    }
                    if let fullConfig {
                        section("Server") {
                            row("Public Key", value: fullConfig.peers.first?.publicKey.base64EncodedString() ?? "—")
                            row("Endpoint", value: fullConfig.peers.first?.endpoint?.stringRepresentation ?? "—")
                            row("AllowedIPs", value: fullConfig.peers.first?.allowedIPs.map { $0.stringRepresentation }.joined(separator: ", ") ?? "—")
                            if let keepalive = fullConfig.peers.first?.persistentKeepAlive {
                                row("Keepalive", value: "\(keepalive)s")
                            }
                        }
                        section("Interface") {
                            row("Adresse", value: fullConfig.interface.addresses.map { $0.stringRepresentation }.joined(separator: ", "))
                            row("DNS", value: fullConfig.interface.dns.map { $0.stringRepresentation }.joined(separator: ", "))
                            if let mtu = fullConfig.interface.mtu { row("MTU", value: "\(mtu)") }
                            if let port = fullConfig.interface.listenPort { row("ListenPort", value: "\(port)") }
                        }
                    } else if tunnel?.isConfiguredHere == false {
                        syncingBanner
                    }
                    moveButton
                    deleteButton
                }
                .padding(KW.Space.lg)
            }
        }
        .preferredColorScheme(.dark)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Bearbeiten") { showEdit = true }
                    .foregroundStyle(Color.kwCyan)
            }
        }
        .sheet(isPresented: $showEdit, onDismiss: reload) {
            EditTunnelView(tunnelID: tunnelID)
                .environment(env)
        }
        .task {
            try? await env.tunnelManager.refresh()
            reload()
        }
        .task(id: env.tunnelManager.status(forTunnelID: tunnelID)) {
            await pollStats(status: env.tunnelManager.status(forTunnelID: tunnelID) ?? .invalid)
        }
        .alert("Tunnel löschen?", isPresented: $confirmingDelete) {
            Button("Löschen", role: .destructive, action: deleteTunnel)
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Wird auf allen iCloud-Geräten entfernt.")
        }
    }

    // MARK: - Subviews

    private var header: some View {
        VStack(alignment: .leading, spacing: KW.Space.xs) {
            Text("[ TUNNEL ]").kwLabel()
            Text(tunnel?.name ?? "Lädt…")
                .font(KW.Font.title)
                .foregroundStyle(Color.kwText)
            if let endpoint = tunnel?.serverEndpoint, !endpoint.isEmpty {
                Text(endpoint)
                    .font(KW.Font.telem)
                    .foregroundStyle(Color.kwTextDim)
            }
        }
    }

    private var syncingBanner: some View {
        VStack(alignment: .leading, spacing: KW.Space.xs) {
            Text("iCLOUD-SYNC LÄUFT…")
                .font(KW.Font.label)
                .tracking(2)
                .foregroundStyle(Color.kwCyan)
            Text("Der Tunnel ist via iCloud sichtbar, aber die vollständige Konfiguration ist noch nicht angekommen.")
                .font(KW.Font.body)
                .foregroundStyle(Color.kwTextDim)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .kwPanel()
    }

    private var connectControl: some View {
        let status = env.tunnelManager.status(forTunnelID: tunnelID) ?? .invalid
        return VStack(alignment: .leading, spacing: KW.Space.sm) {
            Text(statusText(for: status))
                .font(KW.Font.label)
                .tracking(2)
                .foregroundStyle(statusColor(for: status))
            VStack(spacing: KW.Space.sm) {
                Button {
                    Task { await toggleConnection(status) }
                } label: {
                    Text(connectLabel(for: status))
                }
                .buttonStyle(KWButtonStyle(
                    tone: status == .connected ? .kwSignal : .kwCyan,
                    filled: status == .disconnected || status == .invalid
                ))
                .disabled(status == .connecting || status == .disconnecting)

                Button {
                    Task { await toggleAutoConnect() }
                } label: {
                    Text(autoConnect ? "Auto-Connect: An" : "Auto-Connect: Aus")
                }
                .buttonStyle(KWButtonStyle(tone: autoConnect ? .kwSignal : .kwTextDim))
            }
            if let connectError {
                Text(connectError)
                    .font(KW.Font.bodySm)
                    .foregroundStyle(Color.kwError)
            }
            if let stats {
                telemetry(stats)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .kwPanel()
    }

    private func telemetry(_ s: TunnelManager.TunnelStats) -> some View {
        HStack(spacing: KW.Space.lg) {
            telemItem("arrow.up", Self.fmtBytes(s.txBytes), .kwCyan)
            telemItem("arrow.down", Self.fmtBytes(s.rxBytes), .kwSignal)
            telemItem("arrow.triangle.2.circlepath",
                      s.lastHandshake.map(Self.relHandshake) ?? "—", .kwTextDim)
        }
        .padding(.top, KW.Space.xs)
    }

    private func telemItem(_ symbol: String, _ value: String, _ tint: Color) -> some View {
        HStack(spacing: KW.Space.xxs) {
            Image(systemName: symbol).foregroundStyle(tint)
            Text(value).foregroundStyle(Color.kwText)
        }
        .font(KW.Font.telem)
    }

    private static func fmtBytes(_ b: UInt64) -> String {
        let f = ByteCountFormatter(); f.countStyle = .binary
        return f.string(fromByteCount: Int64(min(b, UInt64(Int64.max))))
    }

    private static func relHandshake(_ d: Date) -> String {
        let s = max(0, Int(Date().timeIntervalSince(d)))
        if s < 60 { return "vor \(s)s" }
        if s < 3600 { return "vor \(s / 60)m" }
        return "vor \(s / 3600)h"
    }

    /// Pollt die Live-Stats alle 2s, solange verbunden.
    private func pollStats(status: NEVPNStatus) async {
        guard status == .connected else { stats = nil; return }
        while !Task.isCancelled {
            stats = await env.tunnelManager.fetchStats(tunnelID: tunnelID)
            try? await Task.sleep(for: .seconds(2))
        }
    }

    private func connectLabel(for status: NEVPNStatus) -> String {
        switch status {
        case .connected:              return "× Trennen"
        case .connecting:             return "Verbindet…"
        case .disconnecting:          return "Trennt…"
        case .reasserting:            return "Reconnect…"
        default:                      return "▶ Verbinden"
        }
    }

    private func statusText(for status: NEVPNStatus) -> String {
        switch status {
        case .connected:    return "VERBUNDEN"
        case .connecting:   return "VERBINDET…"
        case .disconnecting: return "TRENNT…"
        case .reasserting:  return "RECONNECT…"
        case .disconnected: return "GETRENNT"
        default:            return "STATUS UNBEKANNT"
        }
    }

    private func statusColor(for status: NEVPNStatus) -> Color {
        switch status {
        case .connected:               return .kwSignal
        case .connecting, .reasserting: return .kwWarn
        default:                       return .kwTextDim
        }
    }

    private func toggleConnection(_ status: NEVPNStatus) async {
        connectError = nil
        switch status {
        case .connected, .connecting, .reasserting:
            await env.tunnelManager.disconnect(tunnelID: tunnelID)
        default:
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
            try await env.tunnelManager.setAutoConnect(!autoConnect, tunnelID: tunnelID, displayName: tunnel?.name ?? "Kabelwächter")
        } catch {
            connectError = String(describing: error)
        }
        autoConnect = env.tunnelManager.isAutoConnect(tunnelID: tunnelID)
    }

    private var moveButton: some View {
        let toTV = (tunnel?.target ?? .appleTV) == .phone
        return Button {
            toggleTarget()
        } label: {
            Label(
                toTV ? "Auf Apple TV verschieben" : "Auf iPhone zurückholen",
                systemImage: toTV ? "tv" : "iphone"
            )
        }
        .buttonStyle(KWButtonStyle(tone: .kwCyan))
        .padding(.top, KW.Space.sm)
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            confirmingDelete = true
        } label: {
            Text("Tunnel löschen")
        }
        .buttonStyle(KWButtonStyle(tone: .kwError))
    }

    private func toggleTarget() {
        guard let current = tunnel?.target else { return }
        let newTarget: TunnelTarget = current == .phone ? .appleTV : .phone
        do {
            try env.repository.setTarget(newTarget, forTunnelID: tunnelID)
            reload()
        } catch {
            loadError = String(describing: error)
        }
    }

    @ViewBuilder
    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: KW.Space.sm) {
            Text(title)
                .font(KW.Font.label)
                .tracking(2)
                .textCase(.uppercase)
                .foregroundStyle(Color.kwTextFaint)
            VStack(alignment: .leading, spacing: KW.Space.md) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .kwPanel()
        }
    }

    private func row(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(KW.Font.label)
                .foregroundStyle(Color.kwTextFaint)
            Text(value)
                .font(KW.Font.telem)
                .foregroundStyle(Color.kwText)
                .textSelection(.enabled)
                .lineLimit(2)
                .truncationMode(.middle)
        }
    }

    // MARK: - Actions

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
    NavigationStack {
        TunnelDetailView(tunnelID: UUID())
            .environment(CompanionAppEnvironment.makePreview())
    }
}
