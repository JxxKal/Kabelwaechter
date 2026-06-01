import SwiftUI
import AppKit
import NetworkExtension
import KabelwaechterCore
import KabelwaechterPersistence

/// Icon in der Menüleiste. Spiegelt den globalen Verbindungs-Zustand:
/// gefüllter Lock-Shield, sobald irgendein eigener Tunnel verbunden ist,
/// sonst leere Outline. SwiftUI's `@Observable`-Tracking re-rendert dieses
/// View automatisch, sobald sich `tunnelManager.statuses` ändert.
struct MacMenuBarLabel: View {

    var environment: MacAppEnvironment?

    var body: some View {
        let anyConnected = environment?.tunnelManager.statuses.values.contains { status in
            status == .connected
        } ?? false
        Image(systemName: anyConnected ? "lock.shield.fill" : "lock.shield")
            .accessibilityLabel(anyConnected ? "Kabelwächter — verbunden" : "Kabelwächter — getrennt")
    }
}

/// Inhalt des Menu-Bar-Pulldowns. `.menu`-Style (NSMenu-basiert) erlaubt
/// Sections, Buttons, Dividers — bewusst keine eigenständige Popover-UI,
/// das fühlt sich auf macOS schneller/native-r an.
struct MacMenuBarContent: View {

    var environment: MacAppEnvironment?
    var initError: String?

    @Environment(\.openWindow) private var openWindow

    var body: some View {
        if let env = environment {
            menuContent(env: env)
        } else if let initError {
            Text("Startfehler: \(initError)")
            Divider()
            quitButton
        } else {
            Text("Wird geladen…")
            Divider()
            quitButton
        }
    }

    @ViewBuilder
    private func menuContent(env: MacAppEnvironment) -> some View {
        let me = DeviceIdentity.id
        let allTunnels = (try? env.repository.allTunnels()) ?? []
        let myTunnels = allTunnels
            .filter { $0.isOwned(by: me) }
            .sorted { $0.createdAt < $1.createdAt }
        let connectedTunnel = myTunnels.first { tunnel in
            env.tunnelManager.status(forTunnelID: tunnel.id) == .connected
        }

        // Status-Section
        Section {
            if let t = connectedTunnel {
                Button("✓ Verbunden: \(t.name)") {}
                    .disabled(true)
                Button(t.serverEndpoint) {}
                    .disabled(true)
            } else {
                Button("Getrennt") {}
                    .disabled(true)
            }
        }

        // Tunnel-Quickswitch
        if myTunnels.isEmpty {
            Section("Tunnel") {
                Button("Keine Tunnel auf diesem Mac") {}
                    .disabled(true)
            }
        } else {
            Section("Tunnel") {
                ForEach(myTunnels, id: \.id) { tunnel in
                    tunnelButton(tunnel, env: env)
                }
            }
        }

        // Aktionen
        Section {
            Button("Tunnel verwalten…") {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "main")
            }
            .keyboardShortcut("0", modifiers: .command)

            Button("Über Kabelwächter") {
                NSApp.activate(ignoringOtherApps: true)
                NSApp.orderFrontStandardAboutPanel(nil)
            }
        }

        // Quit
        Section {
            quitButton
        }
    }

    @ViewBuilder
    private func tunnelButton(_ tunnel: TunnelView, env: MacAppEnvironment) -> some View {
        let status = env.tunnelManager.status(forTunnelID: tunnel.id) ?? .invalid
        let label: String = {
            switch status {
            case .connected:                return "✓ \(tunnel.name)"
            case .connecting, .reasserting: return "… \(tunnel.name)"
            case .disconnecting:            return "… \(tunnel.name) (trennt)"
            default:                        return "    \(tunnel.name)"
            }
        }()
        Button(label) {
            Task { await toggleTunnel(tunnel, env: env) }
        }
        .disabled(status == .connecting || status == .disconnecting)
    }

    private var quitButton: some View {
        Button("Kabelwächter beenden") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
    }

    /// Tunnel-Toggle: anderen aktiven Tunnel zuerst trennen (1-Verbindung-
    /// Modell, keine simultanen Tunnel), dann anvisierten Tunnel
    /// verbinden/trennen.
    private func toggleTunnel(_ tunnel: TunnelView, env: MacAppEnvironment) async {
        let current = env.tunnelManager.status(forTunnelID: tunnel.id) ?? .invalid
        if current == .connected || current == .connecting || current == .reasserting {
            await env.tunnelManager.disconnect(tunnelID: tunnel.id)
            return
        }
        // Andere aktive Tunnel zuerst trennen.
        if let all = try? env.repository.allTunnels() {
            for other in all where other.id != tunnel.id {
                let s = env.tunnelManager.status(forTunnelID: other.id) ?? .invalid
                if s == .connected || s == .connecting || s == .reasserting {
                    await env.tunnelManager.disconnect(tunnelID: other.id)
                }
            }
        }
        try? await env.tunnelManager.connect(tunnelID: tunnel.id, displayName: tunnel.name)
    }
}
