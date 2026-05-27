import SwiftUI
import CoreData
import KabelwaechterCore
import KabelwaechterPersistence
import KabelwaechterUI

/// macOS-Hauptfenster (Milestone A): zweispaltig — Sidebar mit den (via iCloud
/// gesyncten) Tunneln, Detail-Spalte mit der Konfiguration. Read-only; der
/// Verbinden-Knopf kommt mit der macOS-Network-Extension (Milestone B).
struct MacContentView: View {

    @Environment(MacAppEnvironment.self) private var env

    @State private var tunnels: [TunnelView] = []
    @State private var selection: UUID?
    @State private var loadError: String?

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 240, ideal: 300, max: 420)
        } detail: {
            detail
        }
        .preferredColorScheme(.dark)
        .task { reload() }
        .onReceive(NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange)) { _ in
            reload()
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: $selection) {
            if let loadError {
                Text(loadError)
                    .font(KW.Font.bodySm)
                    .foregroundStyle(Color.kwError)
            } else if tunnels.isEmpty {
                Text("Noch keine Tunnel. Importiere einen in der iPhone-App — er erscheint via iCloud hier.")
                    .font(KW.Font.bodySm)
                    .foregroundStyle(Color.kwTextDim)
            } else {
                if !phoneTunnels.isEmpty {
                    Section("Meine Tunnel") {
                        ForEach(phoneTunnels, id: \.id, content: row)
                    }
                }
                if !tvTunnels.isEmpty {
                    Section("Apple TV") {
                        ForEach(tvTunnels, id: \.id, content: row)
                    }
                }
            }
        }
        .navigationTitle("Kabelwächter")
    }

    private func row(_ tunnel: TunnelView) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(tunnel.name.isEmpty ? "Unbenannt" : tunnel.name)
                .font(KW.Font.body.weight(.semibold))
            Text(tunnel.serverEndpoint)
                .font(KW.Font.bodySm.monospaced())
                .foregroundStyle(Color.kwTextFaint)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .tag(tunnel.id)
    }

    private var phoneTunnels: [TunnelView] { tunnels.filter { $0.target == .phone } }
    private var tvTunnels: [TunnelView] { tunnels.filter { $0.target == .appleTV } }

    // MARK: - Detail

    @ViewBuilder
    private var detail: some View {
        if let id = selection, let tunnel = tunnels.first(where: { $0.id == id }) {
            TunnelDetailPane(tunnel: tunnel, config: try? env.repository.tunnelConfiguration(id: id))
        } else {
            VStack(spacing: KW.Space.sm) {
                Text("[ KEIN TUNNEL GEWÄHLT ]")
                    .font(KW.Font.label)
                    .tracking(2)
                    .foregroundStyle(Color.kwCyan)
                Text("Wähle links einen Tunnel.")
                    .foregroundStyle(Color.kwTextDim)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.kwBg0)
        }
    }

    // MARK: - Data

    private func reload() {
        do {
            tunnels = try env.repository.allTunnels().sorted { $0.createdAt < $1.createdAt }
            loadError = nil
            if let sel = selection, !tunnels.contains(where: { $0.id == sel }) { selection = nil }
            if selection == nil { selection = tunnels.first?.id }
        } catch {
            loadError = String(describing: error)
        }
    }
}

/// Detail-Spalte: Tunnel-Kopf + Konfiguration (Server/Interface). Verbinden
/// folgt mit der macOS-NE (Milestone B) — bis dahin ein Hinweis.
private struct TunnelDetailPane: View {
    let tunnel: TunnelView
    let config: TunnelConfiguration?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: KW.Space.lg) {
                VStack(alignment: .leading, spacing: KW.Space.xs) {
                    Text(tunnel.name.isEmpty ? "Unbenannt" : tunnel.name)
                        .font(KW.Font.title)
                        .foregroundStyle(Color.kwText)
                    Text(tunnel.serverEndpoint)
                        .font(KW.Font.telem)
                        .foregroundStyle(Color.kwTextDim)
                }

                noticePanel

                if let config {
                    section("Server") {
                        row("Public Key", config.peers.first?.publicKey.base64EncodedString() ?? "—")
                        row("Endpoint", config.peers.first?.endpoint?.stringRepresentation ?? "—")
                        row("AllowedIPs", config.peers.first?.allowedIPs.map { $0.stringRepresentation }.joined(separator: ", ") ?? "—")
                    }
                    section("Interface") {
                        row("Adresse", config.interface.addresses.map { $0.stringRepresentation }.joined(separator: ", "))
                        row("DNS", config.interface.dns.map { $0.stringRepresentation }.joined(separator: ", "))
                        if let mtu = config.interface.mtu { row("MTU", "\(mtu)") }
                    }
                } else {
                    Text("iCloud-Sync läuft – die vollständige Konfiguration ist noch nicht angekommen.")
                        .font(KW.Font.bodySm)
                        .foregroundStyle(Color.kwTextDim)
                }
                Spacer(minLength: 0)
            }
            .padding(KW.Space.gutter)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.kwBg0)
    }

    private var noticePanel: some View {
        HStack(spacing: KW.Space.sm) {
            Image(systemName: "info.circle")
                .foregroundStyle(Color.kwCyan)
            Text("Verbinden folgt: Die native VPN-Anbindung (Network Extension) ist in Arbeit. Aktuell zeigt der Mac die Tunnel nur an.")
                .font(KW.Font.bodySm)
                .foregroundStyle(Color.kwTextDim)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(KW.Space.md)
        .background(Color.kwCyan.opacity(0.08))
        .overlay(Rectangle().stroke(Color.kwLineDim, lineWidth: KW.Border.hairline))
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
            .padding(KW.Space.md)
            .background(Color.kwBg2.opacity(0.6))
            .overlay(Rectangle().stroke(Color.kwLineDim, lineWidth: KW.Border.hairline))
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(KW.Font.label)
                .foregroundStyle(Color.kwTextFaint)
            Text(value)
                .font(KW.Font.telem)
                .foregroundStyle(Color.kwText)
                .textSelection(.enabled)
        }
    }
}
