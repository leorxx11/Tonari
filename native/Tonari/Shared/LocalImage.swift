import SwiftUI
import UIKit

/// Thumbnail of an image stored under Documents (paths like
/// `images/RJ01234567/main.jpg`), decoded off the main thread.
struct LocalImage: View {
    let path: String?
    let size: CGSize

    @Environment(\.displayScale) private var displayScale
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            Color(.secondarySystemBackground)
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "photo")
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(.rect(cornerRadius: 4))
        .task(id: path) {
            guard let path else { return }
            let url = URL.documentsDirectory.appending(path: path)
            guard let source = UIImage(contentsOfFile: url.path) else { return }
            // Aspect-fill target so the cropped thumbnail stays sharp.
            let scale = max(size.width / source.size.width, size.height / source.size.height) * displayScale
            image = await source.byPreparingThumbnail(
                ofSize: CGSize(width: source.size.width * scale, height: source.size.height * scale)
            )
        }
    }
}
