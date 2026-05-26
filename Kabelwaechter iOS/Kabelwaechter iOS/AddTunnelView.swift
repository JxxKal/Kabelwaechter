import SwiftUI
import UniformTypeIdentifiers
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
    @State private var showScanner = false
    @State private var showFileImporter = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.kwBg0.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: KW.Space.lg) {
                        Text("Importiere eine wg-quick-Konfiguration — per QR-Code, aus einer Datei (.conf oder .zip) oder eingefügt. Sie synct via iCloud automatisch auf deinen Apple TV.")
                            .font(KW.Font.body)
                            .foregroundStyle(Color.kwTextDim)
                        importOptions
                        nameField
                        configField
                    }
                    .padding(KW.Space.lg)
                }
            }
            .navigationTitle("Neuer Tunnel")
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
            .alert("Import fehlgeschlagen", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .sheet(isPresented: $showScanner) {
                ZStack(alignment: .topTrailing) {
                    QRScannerView(
                        onScan: { code in
                            wgQuickText = code
                            if name.trimmingCharacters(in: .whitespaces).isEmpty { name = "QR-Tunnel" }
                            showScanner = false
                        },
                        onError: { msg in
                            errorMessage = msg
                            showScanner = false
                        }
                    )
                    .ignoresSafeArea()
                    Button("Schließen") { showScanner = false }
                        .font(KW.Font.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(KW.Space.md)
                }
            }
            .fileImporter(isPresented: $showFileImporter, allowedContentTypes: importTypes) { result in
                handleFileImport(result)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var importOptions: some View {
        HStack(spacing: KW.Space.md) {
            optionButton("QR scannen", icon: "qrcode.viewfinder") { showScanner = true }
            optionButton("Aus Dateien", icon: "folder") { showFileImporter = true }
        }
    }

    private func optionButton(_ title: LocalizedStringKey, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: KW.Space.xs) {
                Image(systemName: icon).font(.title2)
                Text(title).font(KW.Font.bodySm)
            }
            .frame(maxWidth: .infinity)
            .padding(KW.Space.md)
            .background(Color.kwCyan.opacity(0.08))
            .overlay(Rectangle().stroke(Color.kwLineDim, lineWidth: KW.Border.hairline))
            .foregroundStyle(Color.kwCyan)
        }
        .buttonStyle(.plain)
    }

    private var importTypes: [UTType] {
        var types: [UTType] = [.plainText, .text, .zip]
        if let conf = UTType(filenameExtension: "conf") { types.append(conf) }
        return types
    }

    private func handleFileImport(_ result: Result<URL, Error>) {
        switch result {
        case .failure(let error):
            errorMessage = error.localizedDescription
        case .success(let url):
            do {
                let entries = try WgQuickImport.entries(from: url)
                if entries.isEmpty {
                    errorMessage = String(localized: "Keine wg-quick-Konfiguration in der Datei gefunden.")
                } else if entries.count == 1 {
                    // Einzelne Config → ins Feld zum Prüfen/Benennen + Speichern.
                    wgQuickText = entries[0].config
                    if name.trimmingCharacters(in: .whitespaces).isEmpty { name = entries[0].name }
                } else {
                    // Archiv mit mehreren Tunneln → direkt alle importieren,
                    // bereits vorhandene überspringen.
                    var imported = 0
                    var skipped = 0
                    var firstError: String?
                    for entry in entries {
                        do {
                            _ = try env.repository.importWgQuick(entry.config, named: entry.name, target: .phone)
                            imported += 1
                        } catch TunnelRepositoryError.duplicate {
                            skipped += 1
                        } catch let e as TunnelRepositoryError {
                            if firstError == nil { firstError = humanMessage(for: e) }
                        } catch {
                            if firstError == nil { firstError = String(describing: error) }
                        }
                    }
                    if imported > 0 {
                        dismiss()
                    } else if skipped > 0, firstError == nil {
                        errorMessage = String(localized: "Alle \(skipped) Tunnel im Archiv sind bereits vorhanden.")
                    } else {
                        errorMessage = firstError ?? String(localized: "Import fehlgeschlagen.")
                    }
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
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
            _ = try env.repository.importWgQuick(wgQuickText, named: name.trimmingCharacters(in: .whitespaces), target: .phone)
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
    AddTunnelView()
        .environment(CompanionAppEnvironment.makePreview())
}
