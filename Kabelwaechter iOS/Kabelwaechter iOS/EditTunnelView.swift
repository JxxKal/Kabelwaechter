import SwiftUI
import KabelwaechterCore
import KabelwaechterPersistence
import KabelwaechterUI

/// Bearbeitet einen bestehenden Tunnel: Name + wg-quick-Config (vorbefüllt).
/// Speichern aktualisiert denselben Record (gleiche ID → synct als Änderung).
struct EditTunnelView: View {

    @Environment(CompanionAppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss

    let tunnelID: UUID

    @State private var name = ""
    @State private var wgQuickText = ""
    @State private var errorMessage: String?
    @State private var isSaving = false
    @State private var loaded = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.kwBg0.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: KW.Space.lg) {
                        Text("Änderungen syncen via iCloud auf deinen Apple TV. Ein laufender Tunnel übernimmt sie beim nächsten Verbinden.")
                            .font(KW.Font.body)
                            .foregroundStyle(Color.kwTextDim)
                        nameField
                        configField
                    }
                    .padding(KW.Space.lg)
                }
            }
            .navigationTitle("Bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Abbrechen") { dismiss() }
                        .foregroundStyle(Color.kwTextDim)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Sichern", action: save)
                        .foregroundStyle(canSave ? Color.kwCyan : Color.kwTextFaint)
                        .disabled(!canSave || isSaving)
                }
            }
            .alert("Speichern fehlgeschlagen", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .preferredColorScheme(.dark)
        .task { load() }
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
                .frame(minHeight: 280)
                .background(Color.kwBg2)
                .overlay(Rectangle().stroke(Color.kwLineDim, lineWidth: KW.Border.hairline))
                .foregroundStyle(Color.kwText)
        }
    }

    private var canSave: Bool {
        loaded
            && !name.trimmingCharacters(in: .whitespaces).isEmpty
            && !wgQuickText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func load() {
        guard !loaded else { return }
        do {
            let view = try env.repository.tunnel(id: tunnelID)
            name = view.name
            let config = try env.repository.tunnelConfiguration(id: tunnelID)
            wgQuickText = config.asWgQuickConfig()
            loaded = true
        } catch {
            errorMessage = String(localized: "Tunnel konnte nicht geladen werden: \(error.localizedDescription)")
        }
    }

    private func save() {
        isSaving = true
        errorMessage = nil
        do {
            try env.repository.updateTunnel(
                id: tunnelID,
                name: name.trimmingCharacters(in: .whitespaces),
                wgQuickConfig: wgQuickText
            )
            dismiss()
        } catch let error as TunnelRepositoryError {
            errorMessage = humanMessage(for: error)
        } catch {
            errorMessage = String(describing: error)
        }
        isSaving = false
    }

    private func humanMessage(for error: TunnelRepositoryError) -> String {
        switch error {
        case .invalidWgQuickConfig(let detail):
            return String(localized: "Konfiguration ist ungültig: \(detail)")
        case .multiPeerNotSupported:
            return String(localized: "Mehrere [Peer]-Blöcke werden noch nicht unterstützt.")
        case .duplicate(let existingName):
            return String(localized: "Dieser Tunnel ist bereits vorhanden als „\(existingName)“.")
        case .tunnelNotFound, .notConfiguredOnThisDevice:
            return String(describing: error)
        }
    }
}

#Preview {
    EditTunnelView(tunnelID: UUID())
        .environment(CompanionAppEnvironment.makePreview())
}
