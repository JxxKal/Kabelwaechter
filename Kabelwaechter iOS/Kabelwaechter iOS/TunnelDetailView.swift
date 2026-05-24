import SwiftUI
import KabelwaechterCore
import KabelwaechterPersistence

/// Detailansicht eines Tunnels. Read-only in Phase 2.6 — Edit kommt später.
/// Zeigt Template-Felder + Status, plus einen Löschen-Button.
struct TunnelDetailView: View {

    @Environment(CompanionAppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss

    let tunnelID: UUID

    @State private var tunnel: TunnelView?
    @State private var fullConfig: TunnelConfiguration?
    @State private var loadError: String?
    @State private var confirmingDelete = false

    var body: some View {
        ZStack {
            DesignTokens.backgroundGradient.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    if let fullConfig {
                        section("Server") {
                            row("Public Key", value: fullConfig.peers.first?.publicKey.base64EncodedString() ?? "—", monospace: true)
                            row("Endpoint", value: fullConfig.peers.first?.endpoint?.stringRepresentation ?? "—", monospace: true)
                            row("AllowedIPs", value: fullConfig.peers.first?.allowedIPs.map { $0.stringRepresentation }.joined(separator: ", ") ?? "—", monospace: true)
                            if let keepalive = fullConfig.peers.first?.persistentKeepAlive {
                                row("Keepalive", value: "\(keepalive)s")
                            }
                        }
                        section("Interface (dieses Gerät)") {
                            row("Adresse", value: fullConfig.interface.addresses.map { $0.stringRepresentation }.joined(separator: ", "), monospace: true)
                            row("DNS", value: fullConfig.interface.dns.map { $0.stringRepresentation }.joined(separator: ", "), monospace: true)
                            if let mtu = fullConfig.interface.mtu {
                                row("MTU", value: "\(mtu)")
                            }
                            if let port = fullConfig.interface.listenPort {
                                row("ListenPort", value: "\(port)")
                            }
                        }
                    } else if tunnel?.isConfiguredHere == false {
                        notConfiguredBanner
                    }
                    deleteButton
                }
                .padding(20)
            }
        }
        .preferredColorScheme(.dark)
        .task { reload() }
        .alert("Tunnel löschen?", isPresented: $confirmingDelete) {
            Button("Löschen", role: .destructive, action: deleteTunnel)
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Diese Aktion löscht den Tunnel auf allen Geräten und entfernt den Private Key aus dem Schlüsselbund.")
        }
    }

    // MARK: - Subviews

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(tunnel?.name ?? "Lädt…")
                .font(.system(.title, design: .monospaced).weight(.bold))
                .foregroundStyle(DesignTokens.textPrimary)
            if let endpoint = tunnel?.serverEndpoint, !endpoint.isEmpty {
                Text(endpoint)
                    .font(.callout)
                    .foregroundStyle(DesignTokens.textSecondary)
            }
        }
    }

    private var notConfiguredBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Auf diesem Gerät nicht eingerichtet", systemImage: "exclamationmark.shield")
                .foregroundStyle(DesignTokens.accentPrimary)
            Text("Dieser Tunnel wurde via iCloud gesehen, aber es liegt kein Private Key auf diesem Gerät. Importiere eine zweite Konfiguration vom Server-Admin, um ihn hier zu nutzen.")
                .font(.callout)
                .foregroundStyle(DesignTokens.textSecondary)
        }
        .padding(16)
        .background(DesignTokens.surfaceCard, in: RoundedRectangle(cornerRadius: 10))
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            confirmingDelete = true
        } label: {
            Label("Tunnel löschen", systemImage: "trash")
                .frame(maxWidth: .infinity)
                .padding(14)
        }
        .buttonStyle(.borderedProminent)
        .tint(.red.opacity(0.6))
        .padding(.top, 12)
    }

    @ViewBuilder
    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.caption)
                .textCase(.uppercase)
                .foregroundStyle(DesignTokens.textTertiary)
            VStack(alignment: .leading, spacing: 10) {
                content()
            }
            .padding(16)
            .background(DesignTokens.surfaceCard, in: RoundedRectangle(cornerRadius: 10))
        }
    }

    private func row(_ label: String, value: String, monospace: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(DesignTokens.textTertiary)
            Text(value)
                .font(monospace ? .system(.callout, design: .monospaced) : .callout)
                .foregroundStyle(DesignTokens.textPrimary)
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
