import SwiftUI
import KabelwaechterCore

/// Einstellungen (⌘,) der macOS-App: Gerätename ändern. Der Name wird beim
/// Zuweisen von Tunneln denormalisiert mitgesynct — bestehende Zuweisungen
/// übernehmen den neuen Namen erst beim nächsten Zuweisen (denormalisiert).
struct MacSettingsView: View {
    @State private var name: String = DeviceIdentity.name ?? ""
    @State private var saved = false

    var body: some View {
        Form {
            Section("Dieses Gerät") {
                TextField("Gerätename", text: $name)
                    .onSubmit(save)
                Text("Unter diesem Namen erscheinen die Tunnel dieses Macs auf deinen anderen Apple-Geräten.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                HStack {
                    Button("Speichern", action: save)
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    if saved {
                        Text("Gespeichert").font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 440)
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        DeviceIdentity.name = trimmed
        DeviceIdentity.isNameConfirmed = true
        saved = true
    }
}
