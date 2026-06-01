import SwiftUI
import CoreData
import NetworkExtension
import KabelwaechterCore
import KabelwaechterPersistence
import KabelwaechterUI

/// tvOS-Startseite im „Centered Hub"-Design (Variant A): die Tunnel-
/// Visualisierung füllt den Hintergrund, der aktive Tunnel steht als Held
/// mittig, alle Tunnel als fokussierbare Cards unten. Tippen öffnet den
/// Connect-Screen (`TunnelDetailView`).
struct TunnelListView: View {

    @Environment(TVAppEnvironment.self) private var env

    @State private var tunnels: [TunnelView] = []
    @State private var loadError: String?
    @State private var showingAddSheet = false
    @State private var selectedTunnelID: UUID?
    @State private var showOnboarding = !DeviceIdentity.isNameConfirmed
    @State private var showDeviceSettings = false
    @FocusState private var focusedCard: UUID?

    var body: some View {
        NavigationStack {
            ZStack {
                CyberBackdrop(accent: .kwCyan) {
                    TunnelViz(state: heroState, intensity: tunnels.isEmpty ? 0.4 : 0.8)
                }
                .ignoresSafeArea()
                .allowsHitTesting(false)

                VStack(spacing: 0) {
                    topBar
                    Spacer()
                    center
                    Spacer()
                    if !tunnels.isEmpty { cardRow }
                }
                .padding(KW.Space.gutter)
                .padding(.vertical, KW.Space.safeTop)
            }
            .defaultFocus($focusedCard, tunnels.first?.id)
            .navigationDestination(item: $selectedTunnelID) { id in
                TunnelDetailView(tunnelID: id)
            }
            .fullScreenCover(isPresented: $showingAddSheet, onDismiss: reload) {
                AddTunnelView()
            }
            .fullScreenCover(isPresented: $showOnboarding) {
                TVDeviceNameView(isOnboarding: true, onDone: reload).environment(env)
            }
            .fullScreenCover(isPresented: $showDeviceSettings) {
                TVDeviceNameView(isOnboarding: false, onDone: reload).environment(env)
            }
        }
        .preferredColorScheme(.dark)
        .task {
            reload()
            try? await env.tunnelManager.refresh()
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange)) { _ in
            reload()
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack(alignment: .center) {
            HStack(spacing: KW.Space.md) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("[ KABELWÄCHTER ]").kwLabel()
                    (tunnels.isEmpty
                        ? Text("Keine Tunnel")
                        : Text("\(tunnels.count) Tunnel · via iCloud"))
                        .font(KW.Font.telemTV)
                        .foregroundStyle(Color.kwTextDim)
                }
            }
            Spacer()
            Button {
                showDeviceSettings = true
            } label: {
                Group {
                    if let n = DeviceIdentity.name { Text(verbatim: "⚙ \(n)") }
                    else { Text("⚙ Gerät") }
                }
                .lineLimit(1)
                .truncationMode(.tail)
            }
            .buttonStyle(KWButtonStyle(tone: .kwTextDim))
            .frame(width: 360)

            Button {
                showingAddSheet = true
            } label: {
                Text("＋ Manuell")
            }
            .buttonStyle(KWButtonStyle(tone: .kwCyan))
            .frame(width: 320)
        }
        // Eigener Focus-Section, sonst erreicht die Fernbedienung die obere
        // Leiste nicht aus der unteren Karten-Reihe (die ist ebenfalls Section,
        // und tvOS springt nur zwischen Sections – aber nur, wenn beide Seiten
        // explizit Section sind).
        .focusSection()
    }

    // MARK: - Center

    @ViewBuilder
    private var center: some View {
        if let loadError {
            VStack(spacing: KW.Space.md) {
                Text("[ FEHLER ]").kwLabel()
                Text(loadError)
                    .font(KW.Font.telemTV)
                    .foregroundStyle(Color.kwError)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 900)
            }
        } else if tunnels.isEmpty {
            emptyState
        } else if let active = activeTunnel {
            VStack(spacing: KW.Space.lg) {
                Text("ACTIVE PEER")
                    .font(KW.Font.labelTV)
                    .tracking(6)
                    .foregroundStyle(Color.kwSignal)
                Text(active.name)
                    .font(KW.Font.displayTV)
                    .foregroundStyle(Color.kwText)
                    .shadow(color: Color.kwSignal.opacity(0.4), radius: KW.Glow.textShadow)
                Text(active.serverEndpoint.uppercased())
                    .font(KW.Font.telemTV)
                    .tracking(2)
                    .foregroundStyle(Color.kwTextDim)
            }
        } else {
            VStack(spacing: KW.Space.md) {
                Text("STANDBY")
                    .font(KW.Font.labelTV)
                    .tracking(6)
                    .foregroundStyle(Color.kwCyan)
                Text("Tunnel wählen")
                    .font(KW.Font.titleTV)
                    .foregroundStyle(Color.kwText)
            }
        }
    }

    // MARK: - Empty state (Companion-App-QR)

    // QR-Ziel: die iOS-Companion-App. Aktuell der TestFlight-Einladungslink der
    // iOS-Beta; nach App-Store-Veröffentlichung auf die Store-URL umstellen.
    private let companionAppURL = "https://testflight.apple.com/join/23kyR7WK"

    private var emptyState: some View {
        VStack(spacing: KW.Space.xl) {
            Text("[ NOCH KEINE TUNNEL ]")
                .font(KW.Font.labelTV)
                .tracking(6)
                .foregroundStyle(Color.kwCyan)
            HStack(alignment: .center, spacing: KW.Space.xxl) {
                VStack(spacing: KW.Space.md) {
                    QRCodeView(companionAppURL)
                        .frame(width: 300, height: 300)
                        .padding(KW.Space.lg)
                        .background(Color.kwText)
                        .overlay { CornerFrame(color: .kwCyan, size: 20, thickness: 2, inset: -8) }
                    Text("SCAN · MIT · IPHONE")
                        .font(KW.Font.labelTV)
                        .tracking(4)
                        .foregroundStyle(Color.kwTextDim)
                }
                VStack(alignment: .leading, spacing: KW.Space.lg) {
                    Text("Kabelwächter fürs iPhone")
                        .font(KW.Font.h2TV)
                        .foregroundStyle(Color.kwText)
                    stepRow("01", "iPhone-App installieren (QR scannen)")
                    stepRow("02", "Tunnel in der App importieren")
                    stepRow("03", "Auf Apple TV verschieben → erscheint hier via iCloud")
                    Text("Tunnel werden über die iPhone-App verwaltet. Alternativ oben über ＋ Manuell eine wg-quick direkt eingeben.")
                        .font(KW.Font.bodyTV)
                        .foregroundStyle(Color.kwTextDim)
                        .frame(maxWidth: 560, alignment: .leading)
                        .padding(.top, KW.Space.sm)
                }
            }
        }
    }

    private func stepRow(_ number: String, _ text: LocalizedStringKey) -> some View {
        HStack(spacing: KW.Space.md) {
            Text(number)
                .font(KW.Font.telemTV)
                .foregroundStyle(Color.kwCyan)
                .padding(.horizontal, KW.Space.sm)
                .padding(.vertical, KW.Space.xxs)
                .overlay(Rectangle().stroke(Color.kwCyan.opacity(0.5), lineWidth: KW.Border.hairline))
            Text(text)
                .font(KW.Font.bodyTV)
                .foregroundStyle(Color.kwText)
        }
    }

    // MARK: - Card row

    private var cardRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: KW.Space.lg) {
                ForEach(tunnels, id: \.id) { tunnel in
                    Button {
                        selectedTunnelID = tunnel.id
                    } label: {
                        card(for: tunnel)
                    }
                    .buttonStyle(KWCardButtonStyle(
                        accent: .kwCyan,
                        highlighted: connectionState(for: tunnel.id) == .connected
                    ))
                    .frame(width: 560)
                    .focused($focusedCard, equals: tunnel.id)
                }
            }
            .padding(.vertical, KW.Space.sm)
            .padding(.horizontal, 4)
        }
        .frame(height: 240)
        .focusSection()
    }

    private func card(for tunnel: TunnelView) -> some View {
        let state = connectionState(for: tunnel.id)
        let badge: String = {
            if !tunnel.isConfiguredHere { return "SYNC…" }
            if tunnel.isFree { return "FREI" }
            return "TUNNEL"
        }()
        let badgeColor: Color = tunnel.isFree && tunnel.isConfiguredHere ? .kwCyan : .kwTextFaint
        return VStack(alignment: .leading, spacing: KW.Space.sm) {
            HStack {
                Text(badge)
                    .font(KW.Font.labelTV)
                    .tracking(2)
                    .foregroundStyle(badgeColor)
                Spacer()
                Circle()
                    .fill(state.color)
                    .frame(width: 12, height: 12)
                    .shadow(color: state == .idle ? .clear : state.color, radius: 6)
            }
            (tunnel.name.isEmpty ? Text("Unbenannt") : Text(verbatim: tunnel.name))
                .font(KW.Font.h2TV)
                .foregroundStyle(Color.kwText)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
            Text(tunnel.serverEndpoint)
                .font(KW.Font.telemTV)
                .foregroundStyle(Color.kwTextFaint)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .truncationMode(.middle)
        }
    }

    // MARK: - Helpers

    /// Der gerade verbundene Tunnel (für den zentralen Helden), falls einer.
    private var activeTunnel: TunnelView? {
        tunnels.first { connectionState(for: $0.id) == .connected }
    }

    /// Viz-Zustand des Hintergrunds: verbunden > verbindet > idle.
    private var heroState: KWConnectionState {
        var sawConnecting = false
        for t in tunnels {
            switch connectionState(for: t.id) {
            case .connected: return .connected
            case .connecting: sawConnecting = true
            default: break
            }
        }
        return sawConnecting ? .connecting : .idle
    }

    private func connectionState(for id: UUID) -> KWConnectionState {
        switch env.tunnelManager.status(forTunnelID: id) {
        case .connected:                 return .connected
        case .connecting, .reasserting:  return .connecting
        default:                         return .idle
        }
    }

    private func reload() {
        do {
            let me = DeviceIdentity.id
            // Owner-Modell: eigene Tunnel (beanspruchbar/verbindbar) + freie
            // Tunnel (claimable über die Detailansicht). Tunnel anderer
            // Besitzer werden auf dem TV bewusst nicht gezeigt — die Focus-Reihe
            // soll klein bleiben. Legacy `target==.appleTV` ohne Besitzer fällt
            // unter `isFree` (claimable, bis die Onboarding-Migration sie auf
            // dieses TV beansprucht hat).
            tunnels = try env.repository.allTunnels()
                .filter { $0.isOwned(by: me) || $0.isFree }
                .sorted { ($0.isOwned(by: me) ? 0 : 1, $0.createdAt) < ($1.isOwned(by: me) ? 0 : 1, $1.createdAt) }
            loadError = nil
        } catch {
            loadError = String(describing: error)
        }
    }
}

#Preview {
    TunnelListView()
        .environment(TVAppEnvironment.makePreview())
}
