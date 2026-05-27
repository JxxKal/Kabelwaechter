import SwiftUI
import UIKit
import KabelwaechterCore
import KabelwaechterPersistence
import KabelwaechterUI

/// Gerätename setzen — verpflichtendes Erst-Onboarding (`isOnboarding`) und
/// späteres Umbenennen (über das Zahnrad in der Liste). Der Name identifiziert
/// dieses Gerät auf den anderen Apple-Geräten; beim Speichern werden die
/// denormalisierten Namen der eigenen Tunnel aktualisiert.
struct DeviceNameSheet: View {
    @Environment(CompanionAppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss

    var isOnboarding: Bool
    var onDone: () -> Void = {}

    @State private var name: String = DeviceIdentity.name ?? UIDevice.current.name

    private var trimmed: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.kwBg0.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: KW.Space.lg) {
                        Text("Diesem Gerät einen Namen geben")
                            .font(KW.Font.title)
                            .foregroundStyle(Color.kwText)

                        Text("Der Name identifiziert dieses Gerät auf deinen anderen Apple-Geräten. Tunnel, die du hier verwendest, erscheinen auf Mac, iPad und Apple TV unter diesem Namen — und du kannst jeden Tunnel frei einem Gerät zuordnen (immer nur eins gleichzeitig aktiv).")
                            .font(KW.Font.body)
                            .foregroundStyle(Color.kwTextDim)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: KW.Space.sm) {
                            Image(systemName: "qrcode").foregroundStyle(Color.kwCyan)
                            Text("Tipp: Per QR-Code (＋) geht der Import am schnellsten. Tunnel synchronisieren via iCloud auf deine anderen Geräte.")
                                .font(KW.Font.bodySm)
                                .foregroundStyle(Color.kwTextDim)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(KW.Space.md)
                        .background(Color.kwCyan.opacity(0.08))
                        .overlay(Rectangle().stroke(Color.kwLineDim, lineWidth: KW.Border.hairline))

                        VStack(alignment: .leading, spacing: KW.Space.xs) {
                            Text("Gerätename").kwLabel()
                            TextField("z.B. iPhone von Jan", text: $name)
                                .textInputAutocapitalization(.words)
                                .autocorrectionDisabled()
                                .font(KW.Font.body)
                                .padding(KW.Space.md)
                                .background(Color.kwBg2)
                                .overlay(Rectangle().stroke(Color.kwLineDim, lineWidth: KW.Border.hairline))
                                .foregroundStyle(Color.kwText)
                                .submitLabel(.done)
                                .onSubmit(commit)
                        }
                    }
                    .padding(KW.Space.lg)
                }
            }
            .navigationTitle(isOnboarding ? "Einrichten" : "Gerät")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                if !isOnboarding {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Abbrechen") { dismiss() }.foregroundStyle(Color.kwTextDim)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isOnboarding ? "Los geht's" : "Sichern", action: commit)
                        .foregroundStyle(trimmed.isEmpty ? Color.kwTextFaint : Color.kwCyan)
                        .disabled(trimmed.isEmpty)
                }
            }
        }
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled(isOnboarding)
    }

    private func commit() {
        guard !trimmed.isEmpty else { return }
        DeviceIdentity.name = trimmed
        DeviceIdentity.isNameConfirmed = true
        // Denormalisierten Namen auf den eigenen Tunneln aktualisieren, damit
        // andere Geräte die neue Section-Überschrift sehen.
        if let tunnels = try? env.repository.allTunnels() {
            for t in tunnels where t.isOwned(by: DeviceIdentity.id) {
                try? env.repository.assign(tunnelID: t.id, toDeviceID: DeviceIdentity.id, named: trimmed)
            }
        }
        onDone()
        dismiss()
    }
}
