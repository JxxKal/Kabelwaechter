import SwiftUI
import UIKit
import CoreData
import NetworkExtension
import KabelwaechterCore
import KabelwaechterPersistence
import KabelwaechterUI

/// Hauptansicht der Companion-App im „Centered Hub"-Design (Variant A).
/// Zwei Sektionen: eigene (phone) Tunnel — seit der iOS-NE hier verbindbar —
/// und (separiert) die Apple-TV-Tunnel.
///
/// Layout adaptiv (Phase 6): iPhone behält den `NavigationStack` (Push-Detail),
/// das iPad bekommt ein `NavigationSplitView` (Sidebar + Detail-Spalte). Die
/// Liste/Header/Sektionen (`listSurface`) sind geteilt — nur der Container und
/// die Zeilen-Aktion (Push vs. Selektion) unterscheiden sich je nach Idiom.
struct TunnelListView: View {

    @Environment(CompanionAppEnvironment.self) private var env

    @State private var tunnels: [TunnelView] = []
    @State private var loadError: String?
    @State private var showingAddSheet = false
    @State private var selectedTunnelID: UUID?
    @State private var showOnboarding = !DeviceIdentity.isNameConfirmed
    @State private var showDeviceSettings = false

    private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    var body: some View {
        Group {
            if isPad { splitLayout } else { stackLayout }
        }
        .preferredColorScheme(.dark)
        .task {
            try? await env.tunnelManager.refresh()
            reload()
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange)) { _ in
            reload()
        }
        .sheet(isPresented: $showingAddSheet, onDismiss: reload) {
            AddTunnelView()
        }
        .sheet(isPresented: $showOnboarding) {
            DeviceNameSheet(isOnboarding: true, onDone: reload).environment(env)
        }
        .sheet(isPresented: $showDeviceSettings) {
            DeviceNameSheet(isOnboarding: false, onDone: reload).environment(env)
        }
    }

    // MARK: - Layouts

    /// iPhone: unverändertes Push-Verhalten.
    private var stackLayout: some View {
        NavigationStack {
            listSurface
                .navigationDestination(for: UUID.self) { id in
                    TunnelDetailView(tunnelID: id)
                }
        }
    }

    /// iPad: Sidebar (Liste) + Detail-Spalte (selektionsbasiert).
    private var splitLayout: some View {
        NavigationSplitView {
            listSurface
                .navigationSplitViewColumnWidth(min: 340, ideal: 400, max: 520)
        } detail: {
            NavigationStack {
                if let id = selectedTunnelID {
                    TunnelDetailView(tunnelID: id).id(id)
                } else {
                    detailPlaceholder
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
    }

    /// Geteilte Listenfläche: Cyber-Backdrop + scrollbarer Header/Inhalt.
    private var listSurface: some View {
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
    }

    private var detailPlaceholder: some View {
        ZStack {
            CyberBackdrop(showScan: false) {
                TunnelViz(state: heroState, intensity: 0.5)
            }
            .ignoresSafeArea()
            VStack(spacing: KW.Space.md) {
                Text("[ KEIN TUNNEL GEWÄHLT ]")
                    .font(KW.Font.label)
                    .tracking(2)
                    .foregroundStyle(Color.kwCyan)
                Text("Wähle links einen Tunnel.")
                    .font(KW.Font.body)
                    .foregroundStyle(Color.kwTextDim)
            }
        }
    }

    /// Viz-Zustand des Hintergrunds: verbunden > verbindet > idle — nur über
    /// die eigenen (phone) Tunnel, die das iPhone selbst aufbaut.
    private var heroState: KWConnectionState {
        var connecting = false
        for t in tunnels where t.isOwned(by: DeviceIdentity.id) {
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
                showDeviceSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.kwTextDim)
                    .frame(width: 40, height: 40)
                    .overlay(Rectangle().stroke(Color.kwLineDim, lineWidth: KW.Border.hairline))
            }
            .accessibilityLabel(Text("Gerät"))
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
                if !myTunnels.isEmpty {
                    tunnelSection(String(localized: "MEINE TUNNEL · \(myTunnels.count)"), tunnels: myTunnels, mine: true, icon: "iphone")
                }
                if !freeTunnels.isEmpty {
                    tunnelSection(String(localized: "FREI · \(freeTunnels.count)"), tunnels: freeTunnels, mine: false, icon: "tray")
                }
                if !appleTVTunnels.isEmpty {
                    tunnelSection("APPLE TV · \(appleTVTunnels.count)", tunnels: appleTVTunnels, mine: false, icon: "tv")
                }
                ForEach(otherGroups, id: \.id) { group in
                    tunnelSection(group.name, tunnels: group.tunnels, mine: false, icon: "desktopcomputer")
                }
            }
            .padding(.top, KW.Space.sm)
        }
    }

    private var myTunnels: [TunnelView] { tunnels.filter { $0.isOwned(by: DeviceIdentity.id) } }
    private var freeTunnels: [TunnelView] {
        tunnels.filter { $0.isFree && $0.target != .appleTV && !$0.isOwned(by: DeviceIdentity.id) }
    }
    // Übergangs-Brücke: Legacy-Ziel appleTV (bis tvOS aufs Besitzer-Modell umgestellt ist).
    private var appleTVTunnels: [TunnelView] {
        tunnels.filter { $0.target == .appleTV && !$0.isOwned(by: DeviceIdentity.id) }
    }
    private var otherGroups: [(id: String, name: String, tunnels: [TunnelView])] {
        let others = tunnels.filter { !$0.isFree && !$0.isOwned(by: DeviceIdentity.id) && $0.target != .appleTV }
        return Dictionary(grouping: others) { $0.ownerDeviceID ?? "" }
            .map { (id, ts) in (id, ts.first?.ownerDeviceName ?? "Anderes Gerät", ts.sorted { $0.createdAt < $1.createdAt }) }
            .sorted { $0.1 < $1.1 }
    }

    private func tunnelSection(_ title: String, tunnels: [TunnelView], mine: Bool, icon: String) -> some View {
        VStack(alignment: .leading, spacing: KW.Space.sm) {
            Text(verbatim: title)
                .font(KW.Font.label)
                .tracking(2)
                .foregroundStyle(mine ? Color.kwTextFaint : Color.kwCyan)
            ForEach(tunnels, id: \.id) { tunnel in
                rowLink(tunnel, mine: mine, icon: icon)
            }
        }
    }

    /// Zeilen-Aktion je nach Idiom: iPhone pusht (NavigationLink), iPad selektiert.
    @ViewBuilder
    private func rowLink(_ tunnel: TunnelView, mine: Bool, icon: String) -> some View {
        let row = TunnelRow(
            tunnel: tunnel,
            mine: mine,
            icon: icon,
            state: mine ? connectionState(for: tunnel.id) : .idle,
            selected: isPad && selectedTunnelID == tunnel.id
        )
        if isPad {
            Button { selectedTunnelID = tunnel.id } label: { row }
                .buttonStyle(.plain)
        } else {
            NavigationLink(value: tunnel.id) { row }
                .buttonStyle(.plain)
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
            // Auf dem iPad eine sinnvolle Vorauswahl/Bereinigung der Detail-Spalte.
            if isPad {
                if let sel = selectedTunnelID, !tunnels.contains(where: { $0.id == sel }) {
                    selectedTunnelID = nil
                }
                if selectedTunnelID == nil {
                    selectedTunnelID = myTunnels.first?.id ?? tunnels.first?.id
                }
            }
        } catch {
            loadError = String(describing: error)
        }
    }
}

/// Listenzeile für einen Tunnel — Navy-Panel, Hairline, Status-Dot, Chevron.
private struct TunnelRow: View {
    let tunnel: TunnelView
    var mine: Bool = false
    var icon: String = "tv"
    var state: KWConnectionState = .idle
    var selected: Bool = false

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
            // Eigene Tunnel: Status-Punkt (grün, wenn verbunden). Andere
            // (frei / Apple TV / anderes Gerät): neutrales Symbol, nicht verbindbar hier.
            if mine {
                Circle()
                    .fill(dotColor)
                    .frame(width: 8, height: 8)
                    .shadow(color: state == .connected ? Color.kwSignal : .clear, radius: 4)
                    .frame(width: 10)
            } else {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.kwCyan)
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
        .background((selected ? Color.kwCyan.opacity(0.12) : Color.kwBg2.opacity(0.7)))
        .overlay(Rectangle().stroke(selected ? Color.kwCyan : Color.kwLineDim, lineWidth: selected ? 2 : KW.Border.hairline))
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
