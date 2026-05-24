import SwiftUI
import KabelwaechterCore
import KabelwaechterUI

@main
struct Kabelwaechter_tvOSApp: App {

    @State private var environment: TVAppEnvironment?
    @State private var initError: String?

    init() {
        print("Kabelwaechter tvOS startet — App-Group: \(KabelwaechterConstants.appGroupIdentifier)")
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let environment {
                    TunnelListView()
                        .environment(environment)
                } else if let initError {
                    VStack(spacing: 24) {
                        Image(systemName: "xmark.octagon")
                            .font(.system(size: 100))
                            .foregroundStyle(.red)
                        Text("Startfehler")
                            .font(.title)
                            .foregroundStyle(Color.kwText)
                        Text(initError)
                            .font(.body)
                            .foregroundStyle(Color.kwTextDim)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 100)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.kwBg0.ignoresSafeArea())
                } else {
                    ProgressView()
                        .scaleEffect(2.0)
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
        if ProcessInfo.processInfo.arguments.contains("--demo") {
            environment = TVAppEnvironment.makePreview()
            return
        }
        do {
            let env = try TVAppEnvironment.makeProduction()
            // NEVPNManager-Configs vom System laden — Fehler hier nicht fatal
            // (ohne signed Build / ohne Entitlement liefert die API ggf. Fehler,
            // aber die App soll trotzdem starten und die Liste anzeigen).
            try? await env.tunnelManager.refresh()
            environment = env
        } catch {
            initError = String(describing: error)
        }
    }
}
