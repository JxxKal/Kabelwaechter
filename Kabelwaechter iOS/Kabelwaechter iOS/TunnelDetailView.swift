import SwiftUI
import KabelwaechterCore
import KabelwaechterPersistence
import KabelwaechterUI

/// Detailansicht eines Tunnels im Kabelwächter-Design. Read-only Config-Sicht
/// (das iPhone verbindet nicht — Decision #8) plus Löschen.
struct TunnelDetailView: View {

    @Environment(CompanionAppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss

    let tunnelID: UUID

    @State private var tunnel: TunnelView?
    @State private var fullConfig: TunnelConfiguration?
    @State private var loadError: String?
    @State private var confirmingDelete = false
    @State private var showEdit = false

    var body: some View {
        ZStack {
            Color.kwBg0.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: KW.Space.lg) {
                    header
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
        .task { reload() }
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

    private var deleteButton: some View {
        Button(role: .destructive) {
            confirmingDelete = true
        } label: {
            Text("Tunnel löschen")
        }
        .buttonStyle(KWButtonStyle(tone: .kwError))
        .padding(.top, KW.Space.sm)
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
