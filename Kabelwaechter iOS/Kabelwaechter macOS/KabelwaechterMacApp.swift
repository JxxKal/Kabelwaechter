import SwiftUI
import KabelwaechterCore
import KabelwaechterPersistence

/// Einstiegspunkt der nativen macOS-App (Phase 7). Bewusst **kein** Mac
/// Catalyst — eigenständiges macOS-Target, das die geteilten Packages
/// (Core/Persistence/UI) wiederverwendet. CloudKit-Sync teilt sich den
/// iCloud-Container mit iOS/tvOS → der Mac sieht dieselben Tunnel.
///
/// Milestone A: Fenster + Sync + Tunnel-Liste/Detail (read-only). Der
/// VPN-Aufbau (Network Extension + Go-Bridge für macOS) folgt in Milestone B.
@main
struct KabelwaechterMacApp: App {

    @State private var environment: MacAppEnvironment?
    @State private var initError: String?

    var body: some Scene {
        WindowGroup {
            Group {
                if let environment {
                    MacContentView()
                        .environment(environment)
                } else if let initError {
                    bootError(initError)
                } else {
                    ProgressView()
                        .controlSize(.large)
                        .task { bootstrap() }
                }
            }
            .frame(minWidth: 820, minHeight: 520)
            .preferredColorScheme(.dark)
        }
        .defaultSize(width: 1040, height: 680)
    }

    @MainActor
    private func bootstrap() {
        guard environment == nil, initError == nil else { return }
        do {
            environment = try MacAppEnvironment.makeProduction()
        } catch {
            initError = String(describing: error)
        }
    }

    private func bootError(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "xmark.octagon")
                .font(.system(size: 64))
                .foregroundStyle(.red)
            Text("Startfehler")
                .font(.title)
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 600)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
