import SwiftUI
import TonariCore

/// A video's 16:9 picture: its own cover, else the default cover chosen in
/// settings, else the gradient `seed` (the video's id) picks. A cover of
/// another shape, such as a frame grabbed from a portrait video, is shown
/// whole over a blurred fill of itself.
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
                ZStack {
                    LocalImage(path: path, seed: seed).blur(radius: 16, opaque: true)
                    LocalImage(path: path, seed: seed, contentMode: .fit)
                }
            } else {
                CoverPlaceholder(seed: seed)
            }
        }
        .aspectRatio(16 / 9, contentMode: .fit)
        .clipShape(.rect(cornerRadius: cornerRadius))
    }
}
