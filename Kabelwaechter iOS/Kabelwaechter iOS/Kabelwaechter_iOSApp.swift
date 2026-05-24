import SwiftUI
import KabelwaechterCore
import KabelwaechterUI

@main
struct Kabelwaechter_iOSApp: App {

    @State private var environment: CompanionAppEnvironment?
    @State private var initError: String?

    init() {
        print("Kabelwaechter iOS startet — Bundle-Prefix: \(KabelwaechterConstants.BundleIdentifiers.prefix)")
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let environment {
                    TunnelListView()
                        .environment(environment)
                } else if let initError {
                    VStack(spacing: 16) {
                        Image(systemName: "xmark.octagon")
                            .font(.largeTitle)
                            .foregroundStyle(.red)
                        Text("Startfehler")
                            .font(.headline)
                            .foregroundStyle(Color.kwText)
                        Text(initError)
                            .font(.caption)
                            .foregroundStyle(Color.kwTextDim)
                            .multilineTextAlignment(.center)
                            .padding()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.kwBg0.ignoresSafeArea())
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.kwBg0.ignoresSafeArea())
                }
            }
            .preferredColorScheme(.dark)
            .task { await bootstrap() }
        }
    }

    @MainActor
    private func bootstrap() async {
        guard environment == nil, initError == nil else { return }
        // Demo-Modus für Smoke-Tests: `--demo` als Launch-Argument verwendet
        // die InMemory-Sample-Repository (vor-befüllt). Production geht den
        // normalen makeProduction-Pfad.
        if ProcessInfo.processInfo.arguments.contains("--demo") {
            environment = CompanionAppEnvironment.makePreview()
            return
        }
        do {
            environment = try CompanionAppEnvironment.makeProduction()
        } catch {
            initError = String(describing: error)
        }
    }
}
