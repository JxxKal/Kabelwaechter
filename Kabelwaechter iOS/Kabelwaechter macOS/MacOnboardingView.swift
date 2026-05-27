import SwiftUI
import KabelwaechterCore
import KabelwaechterUI

/// Verpflichtendes Erst-Onboarding der macOS-App: Der User gibt **diesem Mac
/// einen Namen**. Erst damit funktioniert das iCloud-Mehrgeräte-Feature sinnvoll
/// — Tunnel erscheinen auf den anderen Apple-Geräten unter diesem Namen und
/// lassen sich frei zuordnen. Der Hinweistext bewirbt den Komfort + den
/// schnellen QR-Import über die iPhone-App.
struct MacOnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = DeviceIdentity.name ?? (Host.current().localizedName ?? "Mac")

    var onDone: () -> Void

    private var trimmed: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        ZStack {
            CyberBackdrop(showScan: false) { TunnelViz(state: .idle, intensity: 0.5) }
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: KW.Space.lg) {
                Text("[ KABELWÄCHTER ]").kwLabel()
                Text("Diesem Mac einen Namen geben")
                    .font(KW.Font.title)
                    .foregroundStyle(Color.kwText)

                Text("Der Name identifiziert diesen Mac auf deinen anderen Apple-Geräten. Tunnel, die du hier verwendest, erscheinen auf iPhone, iPad und Apple TV unter diesem Namen — und du kannst jeden Tunnel frei einem Gerät zuordnen (immer nur auf einem Gerät gleichzeitig aktiv).")
                    .font(KW.Font.body)
                    .foregroundStyle(Color.kwTextDim)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: KW.Space.sm) {
                    Image(systemName: "qrcode")
                        .foregroundStyle(Color.kwCyan)
                    Text("Tipp: Tunnel scannst du am schnellsten per QR-Code in der iPhone-App. Sie synchronisieren via iCloud automatisch hierher und können diesem Mac zugewiesen werden.")
                        .font(KW.Font.bodySm)
                        .foregroundStyle(Color.kwTextDim)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(KW.Space.md)
                .background(Color.kwCyan.opacity(0.08))
                .overlay(Rectangle().stroke(Color.kwLineDim, lineWidth: KW.Border.hairline))

                VStack(alignment: .leading, spacing: KW.Space.xs) {
                    Text("Gerätename").kwLabel()
                    TextField("z.B. MacBook von Jan", text: $name)
                        .textFieldStyle(.plain)
                        .font(KW.Font.body)
                        .padding(KW.Space.md)
                        .background(Color.kwBg2)
                        .overlay(Rectangle().stroke(Color.kwLineDim, lineWidth: KW.Border.hairline))
                        .foregroundStyle(Color.kwText)
                        .onSubmit(commit)
                }

                HStack {
                    Spacer()
                    Button("Los geht's", action: commit)
                        .buttonStyle(.borderedProminent)
                        .disabled(trimmed.isEmpty)
                }
            }
            .padding(KW.Space.page)
            .frame(width: 560)
        }
        .preferredColorScheme(.dark)
        .frame(width: 560, height: 480)
    }

    private func commit() {
        guard !trimmed.isEmpty else { return }
        DeviceIdentity.name = trimmed
        DeviceIdentity.isNameConfirmed = true
        onDone()
        dismiss()
    }
}
