import SwiftUI
import KabelwaechterPersistence

/// Modal-Sheet für den Import einer wg-quick-Config. Zwei Felder
/// (Anzeige-Name + Config-Text), ein Speichern-Button.
struct AddTunnelView: View {

    @Environment(CompanionAppEnvironment.self) private var env
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
                    VStack(alignment: .leading, spacing: 20) {
                        nameField
                        configField
                        if let errorMessage {
                            Label(errorMessage, systemImage: "exclamationmark.triangle")
                                .font(.callout)
                                .foregroundStyle(.orange)
                                .padding()
                                .background(.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Tunnel hinzufügen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Abbrechen") { dismiss() }
                        .foregroundStyle(DesignTokens.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Speichern", action: importTunnel)
                        .foregroundStyle(canImport ? DesignTokens.accentPrimary : DesignTokens.textTertiary)
                        .disabled(!canImport || isImporting)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Anzeige-Name")
                .font(.caption)
                .foregroundStyle(DesignTokens.textTertiary)
                .textCase(.uppercase)
            TextField("Heimnetz", text: $name)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .padding(12)
                .background(DesignTokens.surfaceCard, in: RoundedRectangle(cornerRadius: 8))
                .foregroundStyle(DesignTokens.textPrimary)
        }
    }

    private var configField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("wg-quick-Konfiguration")
                .font(.caption)
                .foregroundStyle(DesignTokens.textTertiary)
                .textCase(.uppercase)
            TextEditor(text: $wgQuickText)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(10)
                .frame(minHeight: 240)
                .background(DesignTokens.surfaceCard, in: RoundedRectangle(cornerRadius: 8))
                .foregroundStyle(DesignTokens.textPrimary)
                .overlay(alignment: .topLeading) {
                    if wgQuickText.isEmpty {
                        Text("[Interface]\nPrivateKey = …\n…")
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(DesignTokens.textTertiary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 18)
                            .allowsHitTesting(false)
                    }
                }
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
        .environment(CompanionAppEnvironment.makePreview())
}
