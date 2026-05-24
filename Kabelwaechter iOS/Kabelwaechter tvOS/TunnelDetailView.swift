import SwiftUI
import NetworkExtension
import KabelwaechterCore
import KabelwaechterPersistence

/// Detailansicht eines Tunnels auf tvOS — inkl. großem Connect/Disconnect-
/// Button. Connect-Wiring (NEVPNManager) kommt in 3.2; hier ist die
/// Button-Aktion noch ein no-op.
struct TunnelDetailView: View {

    @Environment(TVAppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss

    let tunnelID: UUID

    @State private var tunnel: TunnelView?
    @State private var fullConfig: TunnelConfiguration?
    @State private var loadError: String?
    @State private var confirmingDelete = false
    @State private var connectError: String?

    var body: some View {
        ZStack {
            DesignTokens.backgroundGradient.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 40) {
                    header
                    connectControl
                    if let fullConfig {
                        section("Server") {
                            row("Endpoint", value: fullConfig.peers.first?.endpoint?.stringRepresentation ?? "—")
                            row("Public Key", value: fullConfig.peers.first?.publicKey.base64EncodedString() ?? "—", truncate: true)
                            row("AllowedIPs", value: fullConfig.peers.first?.allowedIPs.map { $0.stringRepresentation }.joined(separator: ", ") ?? "—")
                            if let keepalive = fullConfig.peers.first?.persistentKeepAlive {
                                row("Keepalive", value: "\(keepalive)s")
                            }
                        }
                        section("Interface (dieses Apple TV)") {
                            row("Adresse", value: fullConfig.interface.addresses.map { $0.stringRepresentation }.joined(separator: ", "))
                            row("DNS", value: fullConfig.interface.dns.map { $0.stringRepresentation }.joined(separator: ", "))
                            if let mtu = fullConfig.interface.mtu {
                                row("MTU", value: "\(mtu)")
                            }
                        }
                    } else if tunnel?.isConfiguredHere == false {
                        notConfiguredBanner
                    }
                    deleteButton
                }
                .padding(60)
                .frame(maxWidth: 1200, alignment: .leading)
                .frame(maxWidth: .infinity)
            }
        }
        .preferredColorScheme(.dark)
        .task { reload() }
        .alert("Tunnel löschen?", isPresented: $confirmingDelete) {
            Button("Löschen", role: .destructive, action: deleteTunnel)
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Wird auf allen iCloud-Geräten entfernt und der Private Key aus dem Schlüsselbund gelöscht.")
        }
    }

    // MARK: - Subviews

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(tunnel?.name ?? "Lädt…")
                .font(.system(.largeTitle, design: .monospaced).weight(.bold))
                .foregroundStyle(DesignTokens.textPrimary)
            if let endpoint = tunnel?.serverEndpoint, !endpoint.isEmpty {
                Text(endpoint)
                    .font(.title3)
                    .foregroundStyle(DesignTokens.textSecondary)
            }
        }
    }

    private var connectControl: some View {
        let status = env.tunnelManager.status(forTunnelID: tunnelID) ?? .invalid
        return VStack(spacing: 16) {
            Button {
                Task { await toggleConnection(currentStatus: status) }
            } label: {
                Label(connectLabel(for: status), systemImage: connectSymbol(for: status))
                    .font(.title2.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 80)
            }
            .buttonStyle(.borderedProminent)
            .tint(connectTint(for: status))
            .disabled(tunnel?.isConfiguredHere != true || status == .connecting || status == .disconnecting)

            Text(statusText(for: status))
                .font(.callout)
                .foregroundStyle(DesignTokens.textSecondary)

            if let connectError {
                Label(connectError, systemImage: "exclamationmark.triangle")
                    .font(.callout)
                    .foregroundStyle(.orange)
            }
        }
    }

    private func toggleConnection(currentStatus: NEVPNStatus) async {
        connectError = nil
        switch currentStatus {
        case .connected, .connecting, .reasserting:
            env.tunnelManager.disconnect(tunnelID: tunnelID)
        case .disconnected, .disconnecting, .invalid:
            fallthrough
        @unknown default:
            do {
                try await env.tunnelManager.connect(
                    tunnelID: tunnelID,
                    displayName: tunnel?.name ?? "Kabelwächter"
                )
            } catch {
                connectError = String(describing: error)
            }
        }
    }

    private func connectLabel(for status: NEVPNStatus) -> String {
        switch status {
        case .connected: return "Trennen"
        case .connecting: return "Verbindet…"
        case .disconnecting: return "Trennt…"
        case .reasserting: return "Reconnect…"
        case .disconnected, .invalid: return "Verbinden"
        @unknown default: return "Verbinden"
        }
    }

    private func connectSymbol(for status: NEVPNStatus) -> String {
        switch status {
        case .connected: return "shield.fill"
        case .connecting, .reasserting: return "ellipsis.circle"
        case .disconnecting: return "shield.slash"
        default: return "shield.lefthalf.filled"
        }
    }

    private func connectTint(for status: NEVPNStatus) -> Color {
        switch status {
        case .connected, .reasserting: return DesignTokens.accentSuccess
        default: return DesignTokens.accentPrimary
        }
    }

    private func statusText(for status: NEVPNStatus) -> String {
        switch status {
        case .connected: return "Verbunden"
        case .connecting: return "Verbinde…"
        case .disconnecting: return "Trenne…"
        case .reasserting: return "Verbindung wird erneuert…"
        case .disconnected: return "Getrennt"
        case .invalid: return "Status unbekannt"
        @unknown default: return "Status unbekannt"
        }
    }

    private var notConfiguredBanner: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("iCloud-Sync läuft…", systemImage: "arrow.triangle.2.circlepath.icloud")
                .font(.title3.weight(.semibold))
                .foregroundStyle(DesignTokens.accentPrimary)
            Text("Der Tunnel ist via iCloud sichtbar, aber die vollständige Konfiguration ist noch nicht angekommen. Verbinden wird aktiv, sobald der Sync durch ist — meist nach wenigen Sekunden. Bleibt es hängen, prüfe die iCloud-Anmeldung auf diesem Apple TV.")
                .font(.body)
                .foregroundStyle(DesignTokens.textSecondary)
        }
        .padding(28)
        .background(DesignTokens.surfaceCard, in: RoundedRectangle(cornerRadius: 16))
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            confirmingDelete = true
        } label: {
            Label("Tunnel löschen", systemImage: "trash")
                .frame(maxWidth: .infinity, minHeight: 70)
        }
        .buttonStyle(.bordered)
        .tint(.red.opacity(0.8))
    }

    @ViewBuilder
    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.headline)
                .textCase(.uppercase)
                .foregroundStyle(DesignTokens.textTertiary)
            VStack(alignment: .leading, spacing: 16) {
                content()
            }
            .padding(28)
            .background(DesignTokens.surfaceCard, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private func row(_ label: String, value: String, truncate: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.callout)
                .foregroundStyle(DesignTokens.textTertiary)
            Text(value)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(DesignTokens.textPrimary)
                .lineLimit(truncate ? 1 : nil)
                .truncationMode(.middle)
        }
    }

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
            .environment(TVAppEnvironment.makePreview())
    }
}
