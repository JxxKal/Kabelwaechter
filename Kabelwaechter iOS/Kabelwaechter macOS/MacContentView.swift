import SwiftUI
import CoreData
import NetworkExtension
import KabelwaechterCore
import KabelwaechterPersistence
import KabelwaechterUI

/// macOS-Hauptfenster: Sidebar mit den (via iCloud gesyncten) Tunneln,
/// gruppiert nach Besitzer-Gerät (Phase 7 / Milestone-C-Modell): „Meine
/// Tunnel" (diesem Mac zugewiesen, verbindbar), „Frei" (noch keinem Gerät
/// zugeordnet) und je eine Section pro anderem Gerät. Detail-Spalte: zuweisen
/// → verbinden (Milestone B, macOS Network Extension).
struct MacContentView: View {

    @Environment(MacAppEnvironment.self) private var env

    @State private var tunnels: [TunnelView] = []
    @State private var selection: UUID?
    @State private var loadError: String?
    @State private var showOnboarding = !DeviceIdentity.isNameConfirmed
    @State private var showImport = false

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 240, ideal: 300, max: 420)
        } detail: {
            detail
        }
        .preferredColorScheme(.dark)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showImport = true
                } label: {
                    Label("Tunnel importieren", systemImage: "plus")
                }
            }
        }
        .task {
            try? await env.tunnelManager.refresh()
            reload()
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange)) { _ in
            // iCloud-Sync: verwaiste NEVPN-Configs (Tunnel an anderes Gerät
            // übergeben oder gelöscht) aus System-Settings → VPN aufräumen.
            Task { await env.tunnelManager.cleanupOrphanedManagers() }
            reload()
        }
        .sheet(isPresented: $showOnboarding) {
            MacOnboardingView(onDone: reload)
                .interactiveDismissDisabled()
        }
        .sheet(isPresented: $showImport) {
            MacAddTunnelView(onImported: { id in
                reload()
                selection = id
            })
            .environment(env)
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: $selection) {
            if let loadError {
                Text(loadError).font(KW.Font.bodySm).foregroundStyle(Color.kwError)
            } else if tunnels.isEmpty {
                Text("Noch keine Tunnel. Importiere einen in der iPhone-App — er erscheint via iCloud hier und kann diesem Mac zugewiesen werden.")
                    .font(KW.Font.bodySm).foregroundStyle(Color.kwTextDim)
            } else {
                if !myTunnels.isEmpty {
                    Section("Meine Tunnel") { ForEach(myTunnels, id: \.id, content: row) }
                }
                if !freeTunnels.isEmpty {
                    Section("Frei") { ForEach(freeTunnels, id: \.id, content: row) }
                }
                if !appleTVTunnels.isEmpty {
                    Section("Apple TV") { ForEach(appleTVTunnels, id: \.id, content: row) }
                }
                ForEach(otherGroups, id: \.id) { group in
                    Section(group.name) { ForEach(group.tunnels, id: \.id, content: row) }
                }
            }
        }
    }

    private func row(_ tunnel: TunnelView) -> some View {
        let connected = tunnel.isOwned(by: DeviceIdentity.id)
            && env.tunnelManager.status(forTunnelID: tunnel.id) == .connected
        return HStack(spacing: KW.Space.sm) {
            Circle()
                .fill(connected ? Color.kwSignal : Color.kwTextFaint)
                .frame(width: 7, height: 7)
            VStack(alignment: .leading, spacing: 2) {
                Text(tunnel.name.isEmpty ? "Unbenannt" : tunnel.name)
                    .font(KW.Font.body.weight(.semibold))
                Text(tunnel.serverEndpoint)
                    .font(KW.Font.bodySm.monospaced())
                    .foregroundStyle(Color.kwTextFaint)
                    .lineLimit(1).truncationMode(.middle)
            }
        }
        .tag(tunnel.id)
    }

    private var myTunnels: [TunnelView] { tunnels.filter { $0.isOwned(by: DeviceIdentity.id) } }
    // „Frei" = keinem Gerät zugewiesen und nicht (legacy) für die Apple TV markiert.
    private var freeTunnels: [TunnelView] {
        tunnels.filter { $0.isFree && $0.target != .appleTV && !$0.isOwned(by: DeviceIdentity.id) }
    }
    // Übergangs-Brücke: Legacy-Ziel `appleTV`, bis tvOS aufs Besitzer-Modell umgestellt ist (C.2).
    private var appleTVTunnels: [TunnelView] {
        tunnels.filter { $0.target == .appleTV && !$0.isOwned(by: DeviceIdentity.id) }
    }
    private var otherGroups: [(id: String, name: String, tunnels: [TunnelView])] {
        let others = tunnels.filter { !$0.isFree && !$0.isOwned(by: DeviceIdentity.id) && $0.target != .appleTV }
        return Dictionary(grouping: others) { $0.ownerDeviceID ?? "" }
            .map { (id, ts) in (id, ts.first?.ownerDeviceName ?? "Anderes Gerät", ts.sorted { $0.createdAt < $1.createdAt }) }
            .sorted { $0.1 < $1.1 }
    }

    // MARK: - Detail

    @ViewBuilder
    private var detail: some View {
        if let id = selection, tunnels.contains(where: { $0.id == id }) {
            TunnelDetailPane(tunnelID: id, onChange: reload)
                .environment(env)
                .id(id)
        } else {
            VStack(spacing: KW.Space.sm) {
                Text("[ KEIN TUNNEL GEWÄHLT ]").font(KW.Font.label).tracking(2).foregroundStyle(Color.kwCyan)
                Text("Wähle links einen Tunnel.").foregroundStyle(Color.kwTextDim)
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
            if selection == nil { selection = myTunnels.first?.id ?? tunnels.first?.id }
        } catch {
            loadError = String(describing: error)
        }
    }
}

/// Detail-Spalte: Tunnel-Kopf, Zuweisung/Verbinden je nach Besitzer, Config.
private struct TunnelDetailPane: View {
    let tunnelID: UUID
    let onChange: () -> Void
    @Environment(MacAppEnvironment.self) private var env

    @State private var tunnel: TunnelView?
    @State private var config: TunnelConfiguration?
    @State private var connectError: String?
    @State private var autoConnect = false
    @State private var stats: TunnelManager.TunnelStats?
    @State private var confirmingDelete = false

    private var isMine: Bool { tunnel?.ownerDeviceID == DeviceIdentity.id }

    var body: some View {
        ZStack {
            CyberBackdrop(showScan: false) {
                TunnelViz(state: vizState, intensity: isMine ? 0.8 : 0.4)
            }
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: KW.Space.lg) {
                    header
                    ownershipControl
                    commonActions
                    if let config { configView(config) }
                    else if tunnel?.isConfiguredHere == false {
                        Text("iCloud-Sync läuft – die vollständige Konfiguration ist noch nicht angekommen.")
                            .font(KW.Font.bodySm).foregroundStyle(Color.kwTextDim)
                    }
                    Spacer(minLength: 0)
                }
                .padding(KW.Space.gutter)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .task { load() }
        .task(id: env.tunnelManager.status(forTunnelID: tunnelID)) {
            await pollStats()
        }
        .alert("Tunnel löschen?", isPresented: $confirmingDelete) {
            Button("Löschen", role: .destructive) { deleteTunnel() }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Wird auf allen iCloud-Geräten entfernt.")
        }
    }

    /// Hintergrund-Viz-Zustand: nur „aktiv", wenn dieser Mac den Tunnel besitzt.
    private var vizState: KWConnectionState {
        guard isMine else { return .idle }
        switch env.tunnelManager.status(forTunnelID: tunnelID) {
        case .connected: return .connected
        case .connecting, .reasserting: return .connecting
        default: return .idle
        }
    }

    /// Aktionen, die für jeden Tunnel gelten: an die Apple TV schicken (Legacy-
    /// Brücke) und komplett löschen.
    @ViewBuilder
    private var commonActions: some View {
        HStack(spacing: KW.Space.md) {
            if tunnel?.target != .appleTV {
                Button("Auf Apple TV verschieben") { moveToAppleTV() }
                    .buttonStyle(.bordered)
            }
            Button("Tunnel löschen", role: .destructive) { confirmingDelete = true }
                .buttonStyle(.bordered)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: KW.Space.xs) {
            Text(tunnel?.name.isEmpty == false ? tunnel!.name : "Unbenannt")
                .font(KW.Font.title).foregroundStyle(Color.kwText)
            if let ep = tunnel?.serverEndpoint, !ep.isEmpty {
                Text(ep).font(KW.Font.telem).foregroundStyle(Color.kwTextDim)
            }
        }
    }

    // MARK: Besitz/Verbinden

    @ViewBuilder
    private var ownershipControl: some View {
        if isMine {
            connectControl
            Button("Vom Mac entfernen", role: .destructive) { free() }
                .buttonStyle(.bordered)
        } else if tunnel?.isFree == true {
            VStack(alignment: .leading, spacing: KW.Space.sm) {
                Text("Dieser Tunnel ist keinem Gerät zugewiesen.")
                    .font(KW.Font.bodySm).foregroundStyle(Color.kwTextDim)
                Button("Auf diesem Mac verwenden") { claim() }
                    .buttonStyle(.borderedProminent)
            }
        } else {
            VStack(alignment: .leading, spacing: KW.Space.sm) {
                Text("In Verwendung auf \(tunnel?.ownerDeviceName ?? "anderem Gerät").")
                    .font(KW.Font.bodySm).foregroundStyle(Color.kwTextDim)
                Button("Auf diesem Mac verwenden") { claim() }
                    .buttonStyle(.bordered)
            }
        }
    }

    private var connectControl: some View {
        let status = env.tunnelManager.status(forTunnelID: tunnelID) ?? .invalid
        return VStack(alignment: .leading, spacing: KW.Space.sm) {
            HStack(spacing: KW.Space.md) {
                Button(action: { Task { await toggleConnection(status) } }) {
                    Text(connectLabel(status)).frame(minWidth: 120)
                }
                .buttonStyle(.borderedProminent)
                .disabled(status == .connecting || status == .disconnecting || tunnel?.isConfiguredHere == false)

                Toggle("Auto-Connect", isOn: Binding(
                    get: { autoConnect },
                    set: { _ in Task { await toggleAutoConnect() } }
                ))
                .toggleStyle(.switch)
            }
            Text(statusText(status)).font(KW.Font.label).tracking(1).foregroundStyle(statusColor(status))
            if let stats { telemetry(stats) }
            if let connectError { Text(connectError).font(KW.Font.bodySm).foregroundStyle(Color.kwError) }
        }
    }

    private func telemetry(_ s: TunnelManager.TunnelStats) -> some View {
        HStack(spacing: KW.Space.lg) {
            Label(Self.bytes(s.txBytes), systemImage: "arrow.up")
            Label(Self.bytes(s.rxBytes), systemImage: "arrow.down")
            Label(s.lastHandshake.map(Self.rel) ?? "—", systemImage: "arrow.triangle.2.circlepath")
        }
        .font(KW.Font.telem).foregroundStyle(Color.kwTextDim)
    }

    private func configView(_ c: TunnelConfiguration) -> some View {
        VStack(alignment: .leading, spacing: KW.Space.lg) {
            section("Server") {
                row("Public Key", c.peers.first?.publicKey.base64EncodedString() ?? "—")
                row("Endpoint", c.peers.first?.endpoint?.stringRepresentation ?? "—")
                row("AllowedIPs", c.peers.first?.allowedIPs.map { $0.stringRepresentation }.joined(separator: ", ") ?? "—")
            }
            section("Interface") {
                row("Adresse", c.interface.addresses.map { $0.stringRepresentation }.joined(separator: ", "))
                row("DNS", c.interface.dns.map { $0.stringRepresentation }.joined(separator: ", "))
                if let mtu = c.interface.mtu { row("MTU", "\(mtu)") }
            }
        }
    }

    @ViewBuilder
    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: KW.Space.sm) {
            Text(title).font(KW.Font.label).tracking(2).textCase(.uppercase).foregroundStyle(Color.kwTextFaint)
            VStack(alignment: .leading, spacing: KW.Space.md) { content() }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(KW.Space.md)
                .background(Color.kwBg2.opacity(0.6))
                .overlay(Rectangle().stroke(Color.kwLineDim, lineWidth: KW.Border.hairline))
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label).font(KW.Font.label).foregroundStyle(Color.kwTextFaint)
            Text(value).font(KW.Font.telem).foregroundStyle(Color.kwText).textSelection(.enabled)
        }
    }

    // MARK: Aktionen

    private func load() {
        do {
            tunnel = try env.repository.tunnel(id: tunnelID)
            config = try? env.repository.displayConfiguration(id: tunnelID)
            autoConnect = env.tunnelManager.isAutoConnect(tunnelID: tunnelID)
        } catch { connectError = String(describing: error) }
    }

    private func claim() {
        do {
            try env.repository.assign(tunnelID: tunnelID, toDeviceID: DeviceIdentity.id, named: DeviceIdentity.name ?? "Mac")
            load(); onChange()
        } catch { connectError = String(describing: error) }
    }

    private func free() {
        // remove(...) trennt + entfernt die System-NEVPN-Config; sonst bliebe
        // der Tunnel in macOS Systemeinstellungen → VPN sichtbar.
        Task { await env.tunnelManager.remove(tunnelID: tunnelID) }
        do { try env.repository.freeTunnel(id: tunnelID); load(); onChange() }
        catch { connectError = String(describing: error) }
    }

    /// An die Apple TV schicken: vom Mac lösen (inkl. System-Config-Entfernung)
    /// und Legacy-Ziel `appleTV` setzen, damit die TV-App den Tunnel via Brücke
    /// zeigt (für TVs, die noch nicht aufs Besitzer-Modell migriert sind).
    private func moveToAppleTV() {
        Task { await env.tunnelManager.remove(tunnelID: tunnelID) }
        do {
            try env.repository.freeTunnel(id: tunnelID)
            try env.repository.setTarget(.appleTV, forTunnelID: tunnelID)
            load(); onChange()
        } catch { connectError = String(describing: error) }
    }

    private func deleteTunnel() {
        Task { await env.tunnelManager.remove(tunnelID: tunnelID) }
        do { try env.repository.deleteTunnel(id: tunnelID); onChange() }
        catch { connectError = String(describing: error) }
    }

    private func toggleConnection(_ status: NEVPNStatus) async {
        connectError = nil
        switch status {
        case .connected, .connecting, .reasserting:
            await env.tunnelManager.disconnect(tunnelID: tunnelID)
        default:
            do { try await env.tunnelManager.connect(tunnelID: tunnelID, displayName: tunnel?.name ?? "Kabelwächter") }
            catch { connectError = String(describing: error) }
        }
        autoConnect = env.tunnelManager.isAutoConnect(tunnelID: tunnelID)
    }

    private func toggleAutoConnect() async {
        connectError = nil
        do { try await env.tunnelManager.setAutoConnect(!autoConnect, tunnelID: tunnelID, displayName: tunnel?.name ?? "Kabelwächter") }
        catch { connectError = String(describing: error) }
        autoConnect = env.tunnelManager.isAutoConnect(tunnelID: tunnelID)
    }

    private func pollStats() async {
        guard env.tunnelManager.status(forTunnelID: tunnelID) == .connected else { stats = nil; return }
        while !Task.isCancelled {
            stats = await env.tunnelManager.fetchStats(tunnelID: tunnelID)
            try? await Task.sleep(for: .seconds(2))
        }
    }

    private func connectLabel(_ s: NEVPNStatus) -> String {
        switch s {
        case .connected: return "Trennen"
        case .connecting: return "Verbindet…"
        case .disconnecting: return "Trennt…"
        default: return "Verbinden"
        }
    }
    private func statusText(_ s: NEVPNStatus) -> String {
        switch s {
        case .connected: return "VERBUNDEN"
        case .connecting: return "VERBINDET…"
        case .disconnecting: return "TRENNT…"
        case .reasserting: return "RECONNECT…"
        case .disconnected: return "GETRENNT"
        default: return "BEREIT"
        }
    }
    private func statusColor(_ s: NEVPNStatus) -> Color {
        switch s {
        case .connected: return .kwSignal
        case .connecting, .reasserting: return .kwWarn
        default: return .kwTextDim
        }
    }

    private static func bytes(_ b: UInt64) -> String {
        let f = ByteCountFormatter(); f.countStyle = .binary
        return f.string(fromByteCount: Int64(min(b, UInt64(Int64.max))))
    }
    private static func rel(_ d: Date) -> String {
        let s = max(0, Int(Date().timeIntervalSince(d)))
        if s < 60 { return "\(s)s" }
        if s < 3600 { return "\(s / 60)m" }
        return "\(s / 3600)h"
    }
}
