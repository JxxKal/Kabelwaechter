import SwiftUI
import KabelwaechterPersistence
import KabelwaechterUI

/// Modal-Sheet für den Import einer wg-quick-Config (iOS) im Kabelwächter-
/// Design. Zwei Felder (Anzeige-Name + Config-Text), Speichern in der Toolbar.
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
                Color.kwBg0.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: KW.Space.lg) {
                        Text("Importiere eine wg-quick-Konfiguration. Sie synct via iCloud automatisch auf deinen Apple TV.")
                            .font(KW.Font.body)
                            .foregroundStyle(Color.kwTextDim)
                        nameField
                        configField
                        if let errorMessage {
                            Text(errorMessage)
                                .font(KW.Font.bodySm)
                                .foregroundStyle(Color.kwError)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(KW.Space.md)
                                .background(Color.kwError.opacity(0.12))
                                .overlay(Rectangle().stroke(Color.kwError.opacity(0.5), lineWidth: KW.Border.hairline))
                        }
                    }
                    .padding(KW.Space.lg)
                }
            }
            .navigationTitle("Tunnel hinzufügen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Abbrechen") { dismiss() }
                        .foregroundStyle(Color.kwTextDim)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Speichern", action: importTunnel)
                        .foregroundStyle(canImport ? Color.kwCyan : Color.kwTextFaint)
                        .disabled(!canImport || isImporting)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: KW.Space.xs) {
            Text("Anzeige-Name").kwLabel()
            TextField("Heimnetz", text: $name)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .font(KW.Font.body)
                .padding(KW.Space.md)
                .background(Color.kwBg2)
                .overlay(Rectangle().stroke(Color.kwLineDim, lineWidth: KW.Border.hairline))
                .foregroundStyle(Color.kwText)
        }
    }

    private var configField: some View {
        VStack(alignment: .leading, spacing: KW.Space.xs) {
            Text("wg-quick-Konfiguration").kwLabel()
            TextEditor(text: $wgQuickText)
                .font(KW.Font.telem)
                .scrollContentBackground(.hidden)
                .padding(KW.Space.sm)
                .frame(minHeight: 240)
                .background(Color.kwBg2)
                .overlay(Rectangle().stroke(Color.kwLineDim, lineWidth: KW.Border.hairline))
                .foregroundStyle(Color.kwText)
                .overlay(alignment: .topLeading) {
                    if wgQuickText.isEmpty {
                        Text("[Interface]\nPrivateKey = …\n…")
                            .font(KW.Font.telem)
                            .foregroundStyle(Color.kwTextFaint)
                            .padding(.horizontal, KW.Space.md)
                            .padding(.vertical, KW.Space.md + 2)
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
