import SwiftUI
import AppKit
import KabelwaechterCore
import KabelwaechterPersistence

/// Einstiegspunkt der nativen macOS-App (Phase 7). Bewusst **kein** Mac
/// Catalyst — eigenständiges macOS-Target, das die geteilten Packages
/// (Core/Persistence/UI) wiederverwendet. CloudKit-Sync teilt sich den
/// iCloud-Container mit iOS/tvOS → der Mac sieht dieselben Tunnel.
///
/// Mit Phase 7 / Milestone D ergänzt um eine **MenuBarExtra** und einen
/// `AppDelegate`, der die App bei geschlossenem Hauptfenster im Menu Bar
/// weiterlaufen lässt — typisches Verhalten für VPN-Clients (verbinden,
/// Tunnel wechseln, ohne das Window wieder aufzumachen).
@main
struct KabelwaechterMacApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @State private var environment: MacAppEnvironment?
    @State private var initError: String?

    init() {
        // Eager bootstrap: damit auch die MenuBarExtra sofort den `env` hat
        // (sonst zeigt sie nur „Wird geladen", solange kein Window auf war).
        do {
            let env = try MacAppEnvironment.makeProduction()
            _environment = State(initialValue: env)
        } catch {
            _initError = State(initialValue: String(describing: error))
        }
    }

    var body: some Scene {
        WindowGroup(id: "main") {
            Group {
                if let environment {
                    MacContentView()
                        .environment(environment)
                } else if let initError {
                    bootError(initError)
                } else {
                    ProgressView()
                        .controlSize(.large)
                }
            }
            .frame(minWidth: 820, minHeight: 520)
            .preferredColorScheme(.dark)
        }
        .defaultSize(width: 1040, height: 680)

        Settings {
            MacSettingsView()
        }

        MenuBarExtra {
            MacMenuBarContent(environment: environment, initError: initError)
                .preferredColorScheme(.dark)
        } label: {
            MacMenuBarLabel(environment: environment)
        }
        .menuBarExtraStyle(.menu)
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

/// Hält die App nach Schließen des letzten Fensters am Leben — das Menu-Bar-
/// Icon bleibt sichtbar, der eventuell verbundene Tunnel läuft weiter (der
/// Tunnel lebt zwar ohnehin in der Network Extension, aber Statusanzeige +
/// Quickswitch funktionieren nur, solange die App-Prozess läuft).
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
