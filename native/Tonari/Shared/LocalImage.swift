import SwiftUI
import UIKit

/// Image stored under Documents (paths like `images/RJ01234567/main.jpg`),
/// decoded off the main thread at the size it is shown and cached.
struct LocalImage: View {
    let path: String?
    var contentMode = ContentMode.fill

    @Environment(\.displayScale) private var displayScale
    @State private var image: UIImage?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color(.secondarySystemBackground)
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: contentMode)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                } else {
                    Image(systemName: "photo").foregroundStyle(.tertiary)
                }
            }
            .task(id: TaskKey(path: path, width: proxy.size.width)) {
                image = await ThumbnailCache.shared.image(path: path, size: proxy.size, scale: displayScale)
            }
        }
        .clipped()
    }

    private struct TaskKey: Hashable {
        let path: String?
        let width: CGFloat
    }
}

/// Full-width image at its natural aspect ratio, for inline pictures.
struct FittedLocalImage: View {
    let path: String

    @Environment(\.displayScale) private var displayScale
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFit()
            } else {
                Color(.secondarySystemBackground).aspectRatio(16 / 9, contentMode: .fit)
            }
        }
        .task(id: path) {
            image = await ThumbnailCache.shared.fitted(path: path, width: 440, scale: displayScale)
        }
    }
}

@MainActor
final class ThumbnailCache {
    static let shared = ThumbnailCache()

    private let cache = NSCache<NSString, UIImage>()

    func fitted(path: String, width: CGFloat, scale: CGFloat) async -> UIImage? {
        let url = URL.documentsDirectory.appending(path: path)
        guard let source = UIImage(contentsOfFile: url.path) else { return nil }
        let height = width * source.size.height / source.size.width
        return await image(path: path, size: CGSize(width: width, height: height), scale: scale)
    }

    func image(path: String?, size: CGSize, scale: CGFloat) async -> UIImage? {
        guard let path, size.width > 0, size.height > 0 else { return nil }
        let key = "\(path)@\(Int(size.width * scale))x\(Int(size.height * scale))" as NSString
        if let cached = cache.object(forKey: key) { return cached }
        let url = URL.documentsDirectory.appending(path: path)
        guard let source = UIImage(contentsOfFile: url.path) else { return nil }
        // Aspect-fill target so a cropped thumbnail stays sharp.
        let factor = max(size.width / source.size.width, size.height / source.size.height) * scale
        let target = CGSize(width: source.size.width * factor, height: source.size.height * factor)
        guard let thumbnail = await source.byPreparingThumbnail(ofSize: target) else { return nil }
        cache.setObject(thumbnail, forKey: key)
        return thumbnail
    }
}
