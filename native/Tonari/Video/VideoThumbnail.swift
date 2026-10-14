import SwiftUI
import TonariCore

/// A video's 16:9 picture: its own cover, else the default cover chosen in
/// settings, else the gradient `seed` (the video's id) picks.
struct VideoThumbnail: View {
    let coverPath: String?
    let seed: String?
    var cornerRadius: CGFloat = 8

    /// Relative to Documents, under the Flutter build's key.
    static let defaultCoverKey = "video.defaultCoverPath"
    @AppStorage(Self.defaultCoverKey) private var defaultCover: String?

    var body: some View {
        Group {
            if let path = coverPath ?? defaultCover {
                LocalImage(path: path, seed: seed)
            } else {
                CoverPlaceholder(seed: seed)
            }
        }
        .aspectRatio(16 / 9, contentMode: .fit)
        .clipShape(.rect(cornerRadius: cornerRadius))
    }
}
