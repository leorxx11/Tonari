import SwiftUI
import TonariCore

/// A video's 16:9 picture: its own cover, else the default cover chosen in
/// settings, else a film glyph on black.
struct VideoThumbnail: View {
    let coverPath: String?
    var cornerRadius: CGFloat = 8

    /// Relative to Documents, under the Flutter build's key.
    static let defaultCoverKey = "video.defaultCoverPath"
    @AppStorage(Self.defaultCoverKey) private var defaultCover: String?

    var body: some View {
        Group {
            if let path = coverPath ?? defaultCover {
                LocalImage(path: path)
            } else {
                ZStack {
                    Color.black
                    Image(systemName: "film").foregroundStyle(.white.opacity(0.6))
                }
            }
        }
        .aspectRatio(16 / 9, contentMode: .fit)
        .clipShape(.rect(cornerRadius: cornerRadius))
    }
}
