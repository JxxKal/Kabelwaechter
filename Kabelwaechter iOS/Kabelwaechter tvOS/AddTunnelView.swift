import SwiftUI
import KabelwaechterPersistence

/// tvOS-Variante des wg-quick-Imports. Das System-Onscreen-Keyboard auf der
/// Siri-Remote ist schmerzhaft — ein externes Bluetooth-Keyboard ist
/// empfohlen. Hier nutzen wir `TextField` für den Namen und einen großen
/// mehrzeiligen Input für die Config (TextEditor auf tvOS heißt
/// `TextField(axis: .vertical, lineLimit: …)`).
struct AddTunnelView: View {

    @Environment(TVAppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var wgQuickText: String = ""
    @State private var errorMessage: String?
    @State private var isImporting = false

    var body: some View {
        NavigationStack {
            ZStack {
                DesignTokens.backgroundGradient.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 32) {
                    Text("Tunnel hinzufügen")
                        .font(.largeTitle.bold())
                        .foregroundStyle(DesignTokens.textPrimary)

                    nameField
                    configField

                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle")
                            .font(.title3)
                            .foregroundStyle(.orange)
                            .padding(20)
                            .background(.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                    }

                    HStack(spacing: 24) {
                        Button("Abbrechen") { dismiss() }
                            .buttonStyle(.bordered)
                        Spacer()
                        Button("Speichern", action: importTunnel)
                            .buttonStyle(.borderedProminent)
                            .tint(DesignTokens.accentPrimary)
                            .disabled(!canImport || isImporting)
                    }
                    .padding(.top, 8)
                }
                .padding(60)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Anzeige-Name")
                .font(.headline)
                .foregroundStyle(DesignTokens.textTertiary)
                .textCase(.uppercase)
            TextField("Heimnetz", text: $name)
                .textFieldStyle(.plain)
                .font(.title3)
                .padding(20)
                .background(DesignTokens.surfaceCard, in: RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(DesignTokens.textPrimary)
        }
    }

    private var configField: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("wg-quick-Konfiguration")
                .font(.headline)
                .foregroundStyle(DesignTokens.textTertiary)
                .textCase(.uppercase)
            TextField(
                "[Interface]\nPrivateKey = …\n…",
                text: $wgQuickText,
                axis: .vertical
            )
            .lineLimit(8...20)
            .textFieldStyle(.plain)
            .font(.system(.body, design: .monospaced))
            .padding(20)
            .background(DesignTokens.surfaceCard, in: RoundedRectangle(cornerRadius: 12))
            .foregroundStyle(DesignTokens.textPrimary)
        }
    }

    private var canImport: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && !wgQuickText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func importTunnel() {
        isImporting = true
        errorMessage = nil
        do {
            _ = try env.repository.importWgQuick(wgQuickText, named: name.trimmingCharacters(in: .whitespaces))
            dismiss()
        } catch let error as TunnelRepositoryError {
            errorMessage = humanMessage(for: error)
        } catch {
            errorMessage = String(describing: error)
        }
        isImporting = false
    }

    private func humanMessage(for error: TunnelRepositoryError) -> String {
        switch error {
        case .invalidWgQuickConfig(let detail):
            return "Konfiguration ist ungültig: \(detail)"
        case .multiPeerNotSupported:
            return "Mehrere [Peer]-Blöcke werden noch nicht unterstützt."
        case .tunnelNotFound, .notConfiguredOnThisDevice:
            return String(describing: error)
        }
    }
}

#Preview {
    AddTunnelView()
        .environment(TVAppEnvironment.makePreview())
}
