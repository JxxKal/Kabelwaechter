import SwiftUI
import KabelwaechterPersistence

/// tvOS-Tunnel-Liste. Apple-TV-spezifisch: keine Swipe-Gesten, größere
/// Hit-Targets, Focus-Engine-Highlight via SwiftUI-Default.
struct TunnelListView: View {

    @Environment(TVAppEnvironment.self) private var env

    @State private var tunnels: [TunnelView] = []
    @State private var loadError: String?
    @State private var showingAddSheet = false
    @State private var selectedTunnelID: UUID?

    var body: some View {
        NavigationStack {
            ZStack {
                DesignTokens.backgroundGradient.ignoresSafeArea()
                content
                    .navigationTitle("Kabelwächter")
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                showingAddSheet = true
                            } label: {
                                Label("Tunnel hinzufügen", systemImage: "plus")
                                    .foregroundStyle(DesignTokens.accentPrimary)
                            }
                        }
                    }
                    .sheet(isPresented: $showingAddSheet, onDismiss: reload) {
                        AddTunnelView()
                    }
                    .navigationDestination(item: $selectedTunnelID) { id in
                        TunnelDetailView(tunnelID: id)
                    }
            }
        }
        .preferredColorScheme(.dark)
        .task { reload() }
    }

    @ViewBuilder
    private var content: some View {
        if let error = loadError {
            VStack(spacing: 24) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 80))
                    .foregroundStyle(.orange)
                Text("Tunnel konnten nicht geladen werden")
                    .font(.title2)
                    .foregroundStyle(DesignTokens.textPrimary)
                Text(error)
                    .font(.body)
                    .foregroundStyle(DesignTokens.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 80)
            }
        } else if tunnels.isEmpty {
            emptyState
        } else {
            grid
        }
    }

    private var emptyState: some View {
        VStack(spacing: 32) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 160))
                .foregroundStyle(DesignTokens.accentPrimary.opacity(0.8))
            Text("Noch keine Tunnel")
                .font(.system(.largeTitle, design: .monospaced).weight(.bold))
                .foregroundStyle(DesignTokens.textPrimary)
            Text("Tunnel werden via iCloud vom iPhone übertragen — oder manuell mit „Tunnel hinzufügen“ einlesen.")
                .font(.title3)
                .multilineTextAlignment(.center)
                .foregroundStyle(DesignTokens.textSecondary)
                .padding(.horizontal, 120)
        }
    }

    private var grid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 480, maximum: 720), spacing: 32)], spacing: 32) {
                ForEach(tunnels, id: \.id) { tunnel in
                    TunnelCard(tunnel: tunnel) {
                        selectedTunnelID = tunnel.id
                    }
                }
            }
            .padding(40)
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

private struct TunnelCard: View {
    let tunnel: TunnelView
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 24) {
                statusDot
                VStack(alignment: .leading, spacing: 8) {
                    Text(tunnel.name.isEmpty ? "Unbenannt" : tunnel.name)
                        .font(DesignTokens.brandFont)
                        .foregroundStyle(DesignTokens.textPrimary)
                    Text(tunnel.serverEndpoint)
                        .font(.body)
                        .foregroundStyle(DesignTokens.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(DesignTokens.textTertiary)
            }
            .padding(28)
            .frame(maxWidth: .infinity)
            .background(DesignTokens.surfaceCard, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.card)
    }

    private var statusDot: some View {
        Circle()
            .fill(tunnel.isConfiguredHere ? DesignTokens.accentSuccess : DesignTokens.textTertiary)
            .frame(width: 18, height: 18)
            .shadow(color: tunnel.isConfiguredHere ? DesignTokens.accentSuccess.opacity(0.7) : .clear,
                    radius: 8)
    }
}

#Preview {
    TunnelListView()
        .environment(TVAppEnvironment.makePreview())
}
