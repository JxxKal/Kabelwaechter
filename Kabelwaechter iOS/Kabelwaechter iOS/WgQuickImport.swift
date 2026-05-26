import Foundation
import Compression

/// Liest importierte Dateien zu wg-quick-Einträgen ein — Parität zum offiziellen
/// WireGuard-iOS-Client: einzelne `.conf`/Textdatei **oder** ein `.zip`-Archiv
/// mit mehreren Configs. ZIP wird ohne Dritt-Bibliothek gelesen (eigener
/// Central-Directory-Parser + DEFLATE via Apples `Compression`-Framework) —
/// minimale Abhängigkeitsfläche für eine VPN-App.
enum WgQuickImport {

    struct Entry {
        let name: String
        let config: String
    }

    enum ImportError: LocalizedError {
        case notReadable
        case badZip

        var errorDescription: String? {
            switch self {
            case .notReadable: return String(localized: "Datei ist kein lesbarer Text.")
            case .badZip: return String(localized: "ZIP-Archiv konnte nicht gelesen werden.")
            }
        }
    }

    /// Liest eine Security-Scoped-URL (z.B. aus „Dateien"/iCloud) zu Einträgen.
    static func entries(from url: URL) throws -> [Entry] {
        let needsStop = url.startAccessingSecurityScopedResource()
        defer { if needsStop { url.stopAccessingSecurityScopedResource() } }

        let data = try Data(contentsOf: url)
        let isZip = url.pathExtension.lowercased() == "zip"
            || data.starts(with: [0x50, 0x4B, 0x03, 0x04])

        if isZip {
            return try confEntries(fromZip: [UInt8](data))
        }
        guard let text = String(data: data, encoding: .utf8) else {
            throw ImportError.notReadable
        }
        let name = url.deletingPathExtension().lastPathComponent
        return [Entry(name: name, config: text)]
    }

    // MARK: - Minimaler ZIP-Reader

    private static func confEntries(fromZip bytes: [UInt8]) throws -> [Entry] {
        // End-of-Central-Directory (Signatur 0x06054b50) rückwärts suchen.
        let minPos = max(0, bytes.count - 65_557) // 22 + max comment length
        var eocd = -1
        if bytes.count >= 22 {
            var i = bytes.count - 22
            while i >= minPos {
                if bytes[i] == 0x50, bytes[i + 1] == 0x4B, bytes[i + 2] == 0x05, bytes[i + 3] == 0x06 {
                    eocd = i; break
                }
                i -= 1
            }
        }
        guard eocd >= 0 else { throw ImportError.badZip }

        let entryCount = u16(bytes, eocd + 10)
        var p = u32(bytes, eocd + 16) // Offset des Central Directory

        var entries: [Entry] = []
        for _ in 0..<entryCount {
            guard p + 46 <= bytes.count, u32(bytes, p) == 0x02014b50 else { break }
            let method = u16(bytes, p + 10)
            let compSize = u32(bytes, p + 20)
            let uncompSize = u32(bytes, p + 24)
            let fnLen = u16(bytes, p + 28)
            let extraLen = u16(bytes, p + 30)
            let commentLen = u16(bytes, p + 32)
            let localOff = u32(bytes, p + 42)
            let fname = String(decoding: bytes[(p + 46)..<(p + 46 + fnLen)], as: UTF8.self)
            p += 46 + fnLen + extraLen + commentLen

            guard fname.lowercased().hasSuffix(".conf"), !fname.hasSuffix("/") else { continue }

            // Local File Header (Signatur 0x04034b50) → Daten-Offset bestimmen.
            guard localOff + 30 <= bytes.count, u32(bytes, localOff) == 0x04034b50 else { continue }
            let lFnLen = u16(bytes, localOff + 26)
            let lExtraLen = u16(bytes, localOff + 28)
            let dataStart = localOff + 30 + lFnLen + lExtraLen
            guard dataStart + compSize <= bytes.count else { continue }
            let comp = Array(bytes[dataStart..<dataStart + compSize])

            let raw: [UInt8]?
            switch method {
            case 0: raw = comp                                   // stored
            case 8: raw = inflate(comp, expectedSize: uncompSize) // raw DEFLATE
            default: raw = nil
            }
            guard let raw, let text = String(bytes: raw, encoding: .utf8) else { continue }
            let stem = (fname as NSString).lastPathComponent
            let name = (stem as NSString).deletingPathExtension
            entries.append(Entry(name: name, config: text))
        }
        return entries
    }

    /// RAW-DEFLATE (RFC 1951) dekomprimieren — `COMPRESSION_ZLIB` ist Apples
    /// Name dafür (ohne zlib-Header), exakt das ZIP-Verfahren 8.
    private static func inflate(_ src: [UInt8], expectedSize: Int) -> [UInt8]? {
        guard expectedSize > 0, !src.isEmpty else { return expectedSize == 0 ? [] : nil }
        var dst = [UInt8](repeating: 0, count: expectedSize)
        let written = dst.withUnsafeMutableBufferPointer { dstBuf in
            src.withUnsafeBufferPointer { srcBuf in
                compression_decode_buffer(
                    dstBuf.baseAddress!, expectedSize,
                    srcBuf.baseAddress!, src.count,
                    nil, COMPRESSION_ZLIB
                )
            }
        }
        return written == expectedSize ? dst : nil
    }

    // Little-Endian-Reader
    private static func u16(_ b: [UInt8], _ o: Int) -> Int {
        Int(b[o]) | (Int(b[o + 1]) << 8)
    }
    private static func u32(_ b: [UInt8], _ o: Int) -> Int {
        Int(b[o]) | (Int(b[o + 1]) << 8) | (Int(b[o + 2]) << 16) | (Int(b[o + 3]) << 24)
    }
}
