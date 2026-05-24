import SwiftUI
import KabelwaechterPersistence

/// Hauptansicht der Companion-App: Liste aller Tunnel, plus Aktionen für
/// Import und Detail-Bearbeitung.
struct TunnelListView: View {

    @Environment(CompanionAppEnvironment.self) private var env

    @State private var tunnels: [TunnelView] = []
    @State private var loadError: String?
    @State private var showingAddSheet = false

    var body: some View {
        NavigationStack {
            ZStack {
                DesignTokens.backgroundGradient
                    .ignoresSafeArea()

                content
                    .navigationTitle("Tunnel")
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                showingAddSheet = true
                            } label: {
                                Image(systemName: "plus")
                                    .foregroundStyle(DesignTokens.accentPrimary)
                            }
                            .accessibilityLabel(Text("Tunnel hinzufügen"))
                        }
                    }
                    .sheet(isPresented: $showingAddSheet, onDismiss: reload) {
                        AddTunnelView()
                    }
            }
        }
        .preferredColorScheme(.dark)
        .task { reload() }
    }

    @ViewBuilder
    private var content: some View {
        if let error = loadError {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundStyle(.orange)
                Text("Tunnel konnten nicht geladen werden")
                    .foregroundStyle(DesignTokens.textPrimary)
                Text(error)
                    .font(.caption)
                    .foregroundStyle(DesignTokens.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        } else if tunnels.isEmpty {
            emptyState
        } else {
            List(tunnels, id: \.id) { tunnel in
                NavigationLink {
                    TunnelDetailView(tunnelID: tunnel.id)
                } label: {
                    TunnelRow(tunnel: tunnel)
                }
                .listRowBackground(DesignTokens.surfaceCard)
                .listRowSeparatorTint(DesignTokens.textTertiary.opacity(0.3))
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 24) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 64))
                .foregroundStyle(DesignTokens.accentPrimary.opacity(0.8))
            Text("Noch keine Tunnel")
                .font(.title2)
                .foregroundStyle(DesignTokens.textPrimary)
            Text("Tippe auf +, um deine erste WireGuard-Konfiguration einzulesen.")
                .multilineTextAlignment(.center)
                .foregroundStyle(DesignTokens.textSecondary)
                .padding(.horizontal, 40)
        }
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

/// Listenzeile für einen einzelnen Tunnel.
private struct TunnelRow: View {
    let tunnel: TunnelView

    var body: some View {
        HStack(spacing: 14) {
            statusDot
            VStack(alignment: .leading, spacing: 4) {
                Text(tunnel.name.isEmpty ? "Unbenannt" : tunnel.name)
                    .font(DesignTokens.brandFont)
                    .foregroundStyle(DesignTokens.textPrimary)
                Text(tunnel.serverEndpoint)
                    .font(.caption)
                    .foregroundStyle(DesignTokens.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
        }
        .padding(.vertical, 6)
    }

    private var statusDot: some View {
        Circle()
            .fill(tunnel.isConfiguredHere ? DesignTokens.accentSuccess : DesignTokens.textTertiary)
            .frame(width: 10, height: 10)
            .shadow(color: tunnel.isConfiguredHere ? DesignTokens.accentSuccess.opacity(0.6) : .clear,
                    radius: 4)
            .accessibilityLabel(Text(tunnel.isConfiguredHere
                                     ? "Auf diesem Gerät eingerichtet"
                                     : "Auf diesem Gerät nicht eingerichtet"))
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
