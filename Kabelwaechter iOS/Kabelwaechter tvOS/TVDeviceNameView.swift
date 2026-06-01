import SwiftUI
import UIKit
import KabelwaechterCore
import KabelwaechterPersistence
import KabelwaechterUI

/// Gerätename auf tvOS setzen — verpflichtendes Erst-Onboarding (`isOnboarding`)
/// und späteres Umbenennen (über „Gerät" oben links in der Liste).
///
/// Übernimmt im Commit zusätzlich die **Legacy-Migration**: alle Tunnel mit
/// `target == .appleTV` ohne Besitzer werden auf dieses Apple TV beansprucht,
/// damit sie auf den anderen Geräten unter der Section dieses TVs auftauchen
/// (statt unter dem Legacy-„Apple TV"-Bridge-Bucket).
struct TVDeviceNameView: View {

    @Environment(TVAppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss

    var isOnboarding: Bool
    var onDone: () -> Void = {}

    @State private var name: String = DeviceIdentity.name ?? UIDevice.current.name
    @FocusState private var nameFocused: Bool

    private var trimmed: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        ZStack {
            CyberBackdrop(accent: .kwCyan) {
                TunnelViz(state: .idle, intensity: 0.3)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(spacing: KW.Space.xl) {
                VStack(spacing: KW.Space.sm) {
                    Text(isOnboarding ? "[ WILLKOMMEN ]" : "[ GERÄT ]")
                        .font(KW.Font.labelTV)
                        .tracking(6)
                        .foregroundStyle(Color.kwCyan)
                    Text("Diesem Apple TV einen Namen geben")
                        .font(KW.Font.h2TV)
                        .foregroundStyle(Color.kwText)
                        .multilineTextAlignment(.center)
                }

                Text("Der Name identifiziert dieses Apple TV auf deinen anderen Apple-Geräten. Tunnel, die du hier verwendest, erscheinen auf iPhone, iPad und Mac unter diesem Namen — und du kannst jeden Tunnel frei einem Gerät zuordnen (immer nur eins gleichzeitig aktiv).")
                    .font(KW.Font.bodyTV)
                    .foregroundStyle(Color.kwTextDim)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 1100)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: KW.Space.sm) {
                    Image(systemName: "qrcode").foregroundStyle(Color.kwCyan)
                    Text("Tipp: Tunnel importierst du am schnellsten in der iPhone-App per QR-Code. Sie synchronisieren via iCloud auf dieses Apple TV.")
                        .font(KW.Font.telemTV)
                        .foregroundStyle(Color.kwTextDim)
                }
                .frame(maxWidth: 1100, alignment: .leading)
                .padding(KW.Space.md)
                .background(Color.kwCyan.opacity(0.08))
                .overlay(Rectangle().stroke(Color.kwLineDim, lineWidth: KW.Border.hairline))

                VStack(alignment: .leading, spacing: KW.Space.sm) {
                    Text("Gerätename").kwLabel()
                    TextField("z.B. Wohnzimmer Apple TV", text: $name)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .focused($nameFocused)
                        .font(KW.Font.h2TV)
                        .frame(width: 1100)
                }

                HStack(spacing: KW.Space.lg) {
                    if !isOnboarding {
                        Button { dismiss() } label: {
                            Text("Abbrechen").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(KWButtonStyle(tone: .kwTextDim))
                        .frame(width: 420)
                    }
                    Button(action: commit) {
                        Text(isOnboarding ? "Los geht's" : "Sichern")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(KWButtonStyle(tone: .kwCyan, filled: true))
                    .disabled(trimmed.isEmpty)
                    .frame(width: 420)
                }
            }
            .padding(KW.Space.xl)
        }
        .preferredColorScheme(.dark)
        .onAppear { nameFocused = true }
    }

    private func commit() {
        guard !trimmed.isEmpty else { return }
        DeviceIdentity.name = trimmed
        DeviceIdentity.isNameConfirmed = true

        // Eigene Tunnel: denormalisierten Namen aktualisieren (Rename-Fall).
        // Legacy-Brücke: target==.appleTV ohne Besitzer auf dieses TV claimen,
        // damit andere Geräte sie unter „Wohnzimmer Apple TV" sehen statt
        // unter dem Legacy-Bucket.
        if let tunnels = try? env.repository.allTunnels() {
            for t in tunnels {
                if t.isOwned(by: DeviceIdentity.id) {
                    try? env.repository.assign(tunnelID: t.id, toDeviceID: DeviceIdentity.id, named: trimmed)
                } else if t.ownerDeviceID == nil && t.target == .appleTV {
                    try? env.repository.assign(tunnelID: t.id, toDeviceID: DeviceIdentity.id, named: trimmed)
                }
            }
        }
        onDone()
        dismiss()
    }
}
