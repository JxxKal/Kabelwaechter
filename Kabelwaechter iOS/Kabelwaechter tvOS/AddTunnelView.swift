import SwiftUI
import KabelwaechterPersistence

/// tvOS-Variante des wg-quick-Imports. Vollbild + scrollbar, weil die
/// Onscreen-Tastatur viel Platz frisst. Eine Bluetooth-Tastatur ist stark
/// empfohlen — mit der Siri-Remote sind mehrzeilige base64-Keys eine Qual,
/// und vor allem braucht die Config **echte Zeilenumbrüche**: ohne die
/// landet alles in einer Zeile und der Parser wirft `invalidLine`.
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
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        Text("Tunnel hinzufügen")
                            .font(.largeTitle.bold())
                            .foregroundStyle(DesignTokens.textPrimary)

                        Label("Normalerweise importierst du den Tunnel einmal in der iPhone-App — er erscheint dann via iCloud automatisch hier. Dieser manuelle Import ist für ein zweites Apple TV gedacht, das eine eigene Konfiguration braucht.",
                              systemImage: "externaldrive.badge.icloud")
                            .font(.callout)
                            .foregroundStyle(DesignTokens.textSecondary)
                            .padding(20)
                            .background(DesignTokens.surfaceSecondary, in: RoundedRectangle(cornerRadius: 12))

                        Label("Tipp: Bluetooth-Tastatur verbinden. Die Konfiguration braucht echte Zeilenumbrüche zwischen [Interface], den Schlüsseln und [Peer].",
                              systemImage: "keyboard")
                            .font(.callout)
                            .foregroundStyle(DesignTokens.textSecondary)
                            .padding(20)
                            .background(DesignTokens.surfaceSecondary, in: RoundedRectangle(cornerRadius: 12))

                        nameField
                        configField

                        if let errorMessage {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Import fehlgeschlagen", systemImage: "exclamationmark.triangle")
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(.orange)
                                Text(errorMessage)
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundStyle(DesignTokens.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(24)
                            .background(.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                        }

                        HStack(spacing: 24) {
                            Button("Abbrechen") { dismiss() }
                                .buttonStyle(.bordered)
                            Spacer()
                            Button(isImporting ? "Speichert…" : "Speichern", action: importTunnel)
                                .buttonStyle(.borderedProminent)
                                .tint(DesignTokens.accentPrimary)
                                .disabled(!canImport || isImporting)
                        }
                        .padding(.top, 8)
                    }
                    .padding(60)
                    .frame(maxWidth: 1400)
                    .frame(maxWidth: .infinity)
                }
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
                .autocorrectionDisabled()
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
                "[Interface]\nPrivateKey = …\nAddress = 10.0.0.2/32\n\n[Peer]\nPublicKey = …\nEndpoint = …:51820\nAllowedIPs = 0.0.0.0/0",
                text: $wgQuickText,
                axis: .vertical
            )
            .lineLimit(12...30)
            .textFieldStyle(.plain)
            .autocorrectionDisabled()
            .font(.system(.title3, design: .monospaced))
            .padding(24)
            .frame(minHeight: 420, alignment: .topLeading)
            .background(DesignTokens.surfaceCard, in: RoundedRectangle(cornerRadius: 12))
            .foregroundStyle(DesignTokens.textPrimary)
        }
    }

    private var canImport: Bool {
        let configReady = !wgQuickText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return configReady && !name.trimmingCharacters(in: .whitespaces).isEmpty
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
            return "Konfiguration ist ungültig.\n\n\(detail)\n\nHäufigste Ursache auf dem Apple TV: fehlende Zeilenumbrüche — die ganze Config landet in einer Zeile. Mit einer Bluetooth-Tastatur Enter zwischen den Zeilen drücken."
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
