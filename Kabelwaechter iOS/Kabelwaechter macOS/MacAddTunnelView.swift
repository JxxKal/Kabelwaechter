import SwiftUI
import UniformTypeIdentifiers
import KabelwaechterCore
import KabelwaechterPersistence
import KabelwaechterUI

/// Manueller wg-quick-Import am Mac: Name + Konfiguration einfügen oder aus
/// einer Datei (.conf/.txt) laden. Der neue Tunnel ist zunächst **frei** und
/// wird dann diesem Mac zugewiesen („Auf diesem Mac verwenden") — konsistent
/// zum iCloud-Modell (Import erzeugt einen freien Tunnel, Geräte ordnen zu).
struct MacAddTunnelView: View {
    @Environment(MacAppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss

    var onImported: (UUID) -> Void

    @State private var name = ""
    @State private var wgQuickText = ""
    @State private var errorMessage: String?
    @State private var showFileImporter = false

    private var canImport: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && !wgQuickText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: KW.Space.lg) {
            Text("Tunnel importieren").font(KW.Font.title).foregroundStyle(Color.kwText)
            Text("Füge eine wg-quick-Konfiguration ein oder lade sie aus einer Datei. Der Tunnel synct via iCloud und kann diesem Mac zugewiesen werden.")
                .font(KW.Font.bodySm).foregroundStyle(Color.kwTextDim)

            VStack(alignment: .leading, spacing: KW.Space.xs) {
                Text("Anzeige-Name").kwLabel()
                TextField("Heimnetz", text: $name)
                    .textFieldStyle(.plain).font(KW.Font.body)
                    .padding(KW.Space.md).background(Color.kwBg2)
                    .overlay(Rectangle().stroke(Color.kwLineDim, lineWidth: KW.Border.hairline))
                    .foregroundStyle(Color.kwText)
            }

            VStack(alignment: .leading, spacing: KW.Space.xs) {
                HStack {
                    Text("wg-quick-Konfiguration").kwLabel()
                    Spacer()
                    Button("Aus Datei…") { showFileImporter = true }
                        .buttonStyle(.link)
                }
                TextEditor(text: $wgQuickText)
                    .font(KW.Font.telem).scrollContentBackground(.hidden)
                    .padding(KW.Space.sm).frame(minHeight: 200)
                    .background(Color.kwBg2)
                    .overlay(Rectangle().stroke(Color.kwLineDim, lineWidth: KW.Border.hairline))
                    .foregroundStyle(Color.kwText)
            }

            if let errorMessage {
                Text(errorMessage).font(KW.Font.bodySm).foregroundStyle(Color.kwError)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Button("Abbrechen") { dismiss() }
                Spacer()
                Button("Importieren", action: importTunnel)
                    .buttonStyle(.borderedProminent)
                    .disabled(!canImport)
            }
        }
        .padding(KW.Space.page)
        .frame(width: 560, height: 520)
        .background(Color.kwBg0)
        .preferredColorScheme(.dark)
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: importTypes) { result in
            handleFile(result)
        }
    }

    private var importTypes: [UTType] {
        var t: [UTType] = [.plainText, .text]
        if let conf = UTType(filenameExtension: "conf") { t.append(conf) }
        return t
    }

    private func handleFile(_ result: Result<URL, Error>) {
        switch result {
        case .failure(let e): errorMessage = e.localizedDescription
        case .success(let url):
            let needsStop = url.startAccessingSecurityScopedResource()
            defer { if needsStop { url.stopAccessingSecurityScopedResource() } }
            do {
                let text = try String(contentsOf: url, encoding: .utf8)
                wgQuickText = text
                if name.trimmingCharacters(in: .whitespaces).isEmpty {
                    name = url.deletingPathExtension().lastPathComponent
                }
            } catch {
                errorMessage = "Datei konnte nicht gelesen werden."
            }
        }
    }

    private func importTunnel() {
        errorMessage = nil
        do {
            let id = try env.repository.importWgQuick(
                wgQuickText, named: name.trimmingCharacters(in: .whitespaces), target: .phone
            )
            onImported(id)
            dismiss()
        } catch let error as TunnelRepositoryError {
            errorMessage = humanMessage(error)
        } catch {
            errorMessage = String(describing: error)
        }
    }

    private func humanMessage(_ error: TunnelRepositoryError) -> String {
        switch error {
        case .invalidWgQuickConfig(let detail): return "Konfiguration ist ungültig: \(detail)"
        case .multiPeerNotSupported: return "Mehrere [Peer]-Blöcke werden noch nicht unterstützt."
        case .duplicate(let existingName): return "Dieser Tunnel ist bereits vorhanden als \(existingName)."
        case .tunnelNotFound, .notConfiguredOnThisDevice: return String(describing: error)
        }
    }
}
