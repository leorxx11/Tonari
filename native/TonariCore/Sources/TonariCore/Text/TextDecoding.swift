import Foundation

/// Decodes the scripts, readmes and subtitles bundled with works: UTF-8 (or a
/// UTF-16 BOM) first, then Windows Shift-JIS for Japanese releases and
/// GB18030 for Chinese ones.
public enum TextDecoding {
    public static func decode(_ data: Data) -> String {
        if data.starts(with: [0xFF, 0xFE]) || data.starts(with: [0xFE, 0xFF]) {
            return String(data: data, encoding: .utf16)!
        }
        if let utf8 = String(data: data, encoding: .utf8) {
            return utf8.hasPrefix("\u{FEFF}") ? String(utf8.dropFirst()) : utf8
        }
        let shiftJIS = String(data: data, encoding: encoding(.dosJapanese))
        let gb18030 = String(data: data, encoding: encoding(.GB_18030_2000))
        // GBK bytes often decode as valid Shift-JIS too; real Japanese text
        // is full of kana, which a misread Chinese text rarely produces.
        if let shiftJIS, let gb18030 {
            return kanaShare(shiftJIS) > 0.1 ? shiftJIS : gb18030
        }
        return shiftJIS ?? gb18030 ?? String(decoding: data, as: UTF8.self)
    }

    private static func encoding(_ encoding: CFStringEncodings) -> String.Encoding {
        String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(encoding.rawValue)))
    }

    private static func kanaShare(_ text: String) -> Double {
        let wide = text.unicodeScalars.filter { $0.value > 0x7F }
        guard !wide.isEmpty else { return 0 }
        let kana = wide.filter { (0x3040...0x30FF).contains($0.value) }
        return Double(kana.count) / Double(wide.count)
    }
}
