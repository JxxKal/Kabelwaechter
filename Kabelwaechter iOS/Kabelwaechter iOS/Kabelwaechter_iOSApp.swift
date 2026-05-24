import SwiftUI
import KabelwaechterCore

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
                            .foregroundStyle(DesignTokens.textPrimary)
                        Text(initError)
                            .font(.caption)
                            .foregroundStyle(DesignTokens.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(DesignTokens.backgroundGradient.ignoresSafeArea())
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(DesignTokens.backgroundGradient.ignoresSafeArea())
                }
            }
            .preferredColorScheme(.dark)
            .task { await bootstrap() }
        }
    }

    @MainActor
    private func bootstrap() async {
        guard environment == nil, initError == nil else { return }
        do {
            environment = try CompanionAppEnvironment.makeProduction()
        } catch {
            initError = String(describing: error)
        }
    }
}
