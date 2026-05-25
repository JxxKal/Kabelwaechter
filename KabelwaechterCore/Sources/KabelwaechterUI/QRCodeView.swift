// ──────────────────────────────────────────────────────────────────────────
// QRCodeView.swift
// Generiert einen QR-Code aus einem String (CoreImage) und tönt ihn auf das
// Marken-Schema (dunkle Module auf hellem Grund — scannbar + on-brand).
// ──────────────────────────────────────────────────────────────────────────

import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

public struct QRCodeView: View {
    public let string: String
    public var moduleColor: Color
    public var backgroundColor: Color

    public init(_ string: String, moduleColor: Color = .kwBg0, backgroundColor: Color = .kwText) {
        self.string = string
        self.moduleColor = moduleColor
        self.backgroundColor = backgroundColor
    }

    public var body: some View {
        Group {
            if let cg = Self.makeQR(string, dark: moduleColor, light: backgroundColor) {
                Image(decorative: cg, scale: 1, orientation: .up)
                    .interpolation(.none) // QR scharf halten beim Skalieren
                    .resizable()
                    .scaledToFit()
            } else {
                Rectangle().fill(backgroundColor)
            }
        }
    }

    private static let context = CIContext()

    private static func makeQR(_ string: String, dark: Color, light: Color) -> CGImage? {
        let qr = CIFilter.qrCodeGenerator()
        qr.message = Data(string.utf8)
        qr.correctionLevel = "M"
        guard let base = qr.outputImage else { return nil }

        var final = base
        // Graustufen → zwei Markenfarben (dunkel = Module, hell = Grund).
        // Nur auf den App-Plattformen (UIKit); macOS-Paket-Build = schwarz/weiß.
        #if canImport(UIKit)
        let fc = CIFilter.falseColor()
        fc.inputImage = base
        fc.color0 = CIColor(color: UIColor(dark))   // dunkle Module
        fc.color1 = CIColor(color: UIColor(light))  // heller Grund
        final = fc.outputImage ?? base
        #endif

        return context.createCGImage(final, from: final.extent)
    }
}

#if canImport(UIKit)
import UIKit
#endif

#if DEBUG
#Preview {
    ZStack {
        Color.kwBg0
        QRCodeView("https://apps.apple.com/app/kabelwaechter")
            .frame(width: 240, height: 240)
            .padding(24)
            .background(Color.kwText)
    }
}
#endif
