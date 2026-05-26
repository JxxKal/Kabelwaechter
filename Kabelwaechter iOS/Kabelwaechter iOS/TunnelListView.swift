import SwiftUI
import CoreData
import NetworkExtension
import KabelwaechterPersistence
import KabelwaechterUI

/// Hauptansicht der Companion-App im „Centered Hub"-Design (Variant A).
/// Zwei Sektionen: eigene (phone) Tunnel — seit der iOS-NE hier verbindbar —
/// und (separiert) die Apple-TV-Tunnel.
struct TunnelListView: View {

    @Environment(CompanionAppEnvironment.self) private var env

    @State private var tunnels: [TunnelView] = []
    @State private var loadError: String?
    @State private var showingAddSheet = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                // Grid-Hintergrund; Ringe nur, wenn ein phone-Tunnel verbunden ist.
                CyberBackdrop(showScan: false) {
                    TunnelViz(state: heroState, intensity: 0.7)
                }
                .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: KW.Space.lg) {
                        header
                        content
                    }
                    .padding(KW.Space.lg)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: UUID.self) { id in
                TunnelDetailView(tunnelID: id)
            }
            .sheet(isPresented: $showingAddSheet, onDismiss: reload) {
                AddTunnelView()
            }
        }
        .preferredColorScheme(.dark)
        .task {
            try? await env.tunnelManager.refresh()
            reload()
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange)) { _ in
            reload()
        }
    }

    /// Viz-Zustand des Hintergrunds: verbunden > verbindet > idle — nur über
    /// die eigenen (phone) Tunnel, die das iPhone selbst aufbaut.
    private var heroState: KWConnectionState {
        var connecting = false
        for t in tunnels where t.target == .phone {
            switch connectionState(for: t.id) {
            case .connected: return .connected
            case .connecting: connecting = true
            default: break
            }
        }
        return connecting ? .connecting : .idle
    }

    private func connectionState(for id: UUID) -> KWConnectionState {
        switch env.tunnelManager.status(forTunnelID: id) {
        case .connected:                return .connected
        case .connecting, .reasserting: return .connecting
        default:                        return .idle
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: KW.Space.xs) {
                Text("[ KABELWÄCHTER ]").kwLabel()
                Text("Tunnels")
                    .font(KW.Font.title)
                    .foregroundStyle(Color.kwText)
            }
            Spacer()
            Button {
                showingAddSheet = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.kwCyan)
                    .frame(width: 40, height: 40)
                    .background(Color.kwCyan.opacity(0.08))
                    .overlay(Rectangle().stroke(Color.kwLineDim, lineWidth: KW.Border.hairline))
            }
            .accessibilityLabel(Text("Tunnel hinzufügen"))
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if let loadError {
            VStack(alignment: .leading, spacing: KW.Space.sm) {
                Text("[ FEHLER ]")
                    .font(KW.Font.label)
                    .tracking(2)
                    .foregroundStyle(Color.kwError)
                Text(loadError)
                    .font(KW.Font.bodySm)
                    .foregroundStyle(Color.kwTextDim)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .kwPanel()
        } else if tunnels.isEmpty {
            emptyState
        } else {
            VStack(alignment: .leading, spacing: KW.Space.xl) {
                if !phoneTunnels.isEmpty {
                    tunnelSection("MEINE TUNNEL · \(phoneTunnels.count)", tunnels: phoneTunnels, isAppleTV: false)
                }
                if !tvTunnels.isEmpty {
                    tunnelSection("APPLE TV · \(tvTunnels.count)", tunnels: tvTunnels, isAppleTV: true)
                }
            }
            .padding(.top, KW.Space.sm)
        }
    }

    private var phoneTunnels: [TunnelView] { tunnels.filter { $0.target == .phone } }
    private var tvTunnels: [TunnelView] { tunnels.filter { $0.target == .appleTV } }

    private func tunnelSection(_ title: LocalizedStringKey, tunnels: [TunnelView], isAppleTV: Bool) -> some View {
        VStack(alignment: .leading, spacing: KW.Space.sm) {
            Text(title)
                .font(KW.Font.label)
                .tracking(2)
                .foregroundStyle(isAppleTV ? Color.kwCyan : Color.kwTextFaint)
            ForEach(tunnels, id: \.id) { tunnel in
                NavigationLink(value: tunnel.id) {
                    TunnelRow(
                        tunnel: tunnel,
                        isAppleTV: isAppleTV,
                        state: isAppleTV ? .idle : connectionState(for: tunnel.id)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: KW.Space.md) {
            Text("[ NOCH KEINE TUNNEL ]")
                .font(KW.Font.label)
                .tracking(2)
                .foregroundStyle(Color.kwCyan)
            Text("Tippe auf ＋, um eine WireGuard-Konfiguration einzulesen. Sie synct via iCloud automatisch auf deinen Apple TV.")
                .font(KW.Font.body)
                .foregroundStyle(Color.kwTextDim)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, KW.Space.xxl)
    }

    private func reload() {
        do {
            tunnels = try env.repository.allTunnels().sorted { $0.createdAt < $1.createdAt }
            loadError = nil
        } catch {
            loadError = String(describing: error)
        }
    }
}

/// Listenzeile für einen Tunnel — Navy-Panel, Hairline, Status-Dot, Chevron.
private struct TunnelRow: View {
    let tunnel: TunnelView
    var isAppleTV: Bool = false
    var state: KWConnectionState = .idle

    /// Punktfarbe eigener (phone) Tunnel: grün = verbunden, amber = verbindet,
    /// sonst Cyan (vorhanden/verbindbar). Signal-Grün nur bei echter Aktivität.
    private var dotColor: Color {
        switch state {
        case .connected:  return .kwSignal
        case .connecting: return .kwWarn
        default:          return .kwCyan
        }
    }

    var body: some View {
        HStack(spacing: KW.Space.md) {
            // Apple-TV-Tunnel: tv-Symbol (für die TV, hier nicht verbindbar).
            // Eigene Tunnel: Status-Punkt (grün, wenn auf dem iPhone verbunden).
            if isAppleTV {
                Image(systemName: "tv")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.kwCyan)
                    .frame(width: 10)
            } else {
                Circle()
                    .fill(dotColor)
                    .frame(width: 8, height: 8)
                    .shadow(color: state == .connected ? Color.kwSignal : .clear, radius: 4)
                    .frame(width: 10)
            }
            VStack(alignment: .leading, spacing: 4) {
                (tunnel.name.isEmpty ? Text("Unbenannt") : Text(verbatim: tunnel.name))
                    .font(KW.Font.body.weight(.semibold))
                    .foregroundStyle(Color.kwText)
                Text(tunnel.serverEndpoint)
                    .font(KW.Font.bodySm.monospaced())
                    .foregroundStyle(Color.kwTextFaint)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.kwTextFaint)
        }
        .padding(KW.Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.kwBg2.opacity(0.7))
        .overlay(Rectangle().stroke(Color.kwLineDim, lineWidth: KW.Border.hairline))
    }
}

#Preview("Mit Tunneln") {
    TunnelListView()
        .environment(CompanionAppEnvironment.makePreview())
}

#Preview("Leer") {
    TunnelListView()
        .environment(CompanionAppEnvironment(repository: InMemoryTunnelRepository()))
}
