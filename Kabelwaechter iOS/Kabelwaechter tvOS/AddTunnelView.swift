import SwiftUI
import KabelwaechterPersistence
import KabelwaechterUI

/// tvOS-Variante des wg-quick-Imports im Kabelwächter-Design. Vollbild +
/// scrollbar, weil die Onscreen-Tastatur viel Platz frisst. Bluetooth-Tastatur
/// empfohlen — die Config braucht echte Zeilenumbrüche zwischen [Interface],
/// Schlüsseln und [Peer], sonst wirft der Parser `invalidLine`.
struct AddTunnelView: View {

    @Environment(TVAppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var wgQuickText: String = ""
    @State private var errorMessage: String?
    @State private var isImporting = false

    var body: some View {
        ZStack {
            CyberBackdrop(accent: .kwCyan, showScan: false) { Color.clear }
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: KW.Space.xl) {
                    Text("[ TUNNEL HINZUFÜGEN ]").kwLabel()

                    Text("Manueller Import")
                        .font(KW.Font.titleTV)
                        .foregroundStyle(Color.kwText)

                    infoPanel
                    field(label: "Anzeige-Name", placeholder: "Heimnetz", text: $name, mono: false)
                    field(label: "wg-quick-Konfiguration",
                          placeholder: "[Interface]\nPrivateKey = …\nAddress = 10.0.0.2/32\n\n[Peer]\nPublicKey = …\nEndpoint = …:51820\nAllowedIPs = 0.0.0.0/0",
                          text: $wgQuickText, mono: true, multiline: true)

                    if let errorMessage {
                        errorPanel(errorMessage)
                    }

                    HStack(spacing: KW.Space.lg) {
                        Button("Abbrechen") { dismiss() }
                            .buttonStyle(KWButtonStyle(tone: .kwTextDim))
                            .frame(width: 320)
                        Button(action: importTunnel) {
                            isImporting ? Text("Speichert…") : Text("Speichern")
                        }
                        .buttonStyle(KWButtonStyle(tone: .kwCyan, filled: true))
                        .frame(maxWidth: .infinity)
                        .disabled(!canImport || isImporting)
                    }
                }
                .padding(KW.Space.page + KW.Space.lg)
                .frame(maxWidth: 1500)
                .frame(maxWidth: .infinity)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var infoPanel: some View {
        VStack(alignment: .leading, spacing: KW.Space.sm) {
            Text("Normalerweise importierst du den Tunnel in der iPhone-App — er erscheint dann via iCloud automatisch hier. Dieser manuelle Import ist für ein zweites Apple TV mit eigener Konfiguration.")
            Text("Tipp: Bluetooth-Tastatur verbinden. Die Config braucht echte Zeilenumbrüche zwischen [Interface], Schlüsseln und [Peer].")
        }
        .font(KW.Font.bodyTV)
        .foregroundStyle(Color.kwTextDim)
        .kwPanel()
    }

    private func field(label: LocalizedStringKey, placeholder: LocalizedStringKey, text: Binding<String>, mono: Bool, multiline: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: KW.Space.sm) {
            Text(label).kwLabel()
            TextField(placeholder, text: text, axis: multiline ? .vertical : .horizontal)
                .lineLimit(multiline ? 10...28 : 1...1)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .font(mono ? KW.Font.telemTV : KW.Font.bodyTV)
                .foregroundStyle(Color.kwText)
                .padding(KW.Space.lg)
                .frame(minHeight: multiline ? 380 : nil, alignment: .topLeading)
                .background(Color.kwBg2)
                .overlay(Rectangle().stroke(Color.kwLineDim, lineWidth: KW.Border.hairline))
        }
    }

    private func errorPanel(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: KW.Space.sm) {
            Text("[ IMPORT FEHLGESCHLAGEN ]")
                .font(KW.Font.labelTV)
                .tracking(2)
                .foregroundStyle(Color.kwError)
            Text(message)
                .font(KW.Font.telemTV)
                .foregroundStyle(Color.kwText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(KW.Space.lg)
        .background(Color.kwError.opacity(0.12))
        .overlay(Rectangle().stroke(Color.kwError.opacity(0.5), lineWidth: KW.Border.hairline))
    }

    private var canImport: Bool {
        !wgQuickText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !name.trimmingCharacters(in: .whitespaces).isEmpty
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
            return String(localized: "Konfiguration ist ungültig.\n\n\(detail)\n\nHäufigste Ursache auf dem Apple TV: fehlende Zeilenumbrüche — die ganze Config landet in einer Zeile. Mit einer Bluetooth-Tastatur Enter zwischen den Zeilen drücken.")
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
    AddTunnelView()
        .environment(TVAppEnvironment.makePreview())
}
