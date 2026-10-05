import SwiftUI
import TonariCore
import UIKit

/// A DLsite or chobit image, from the URL cache whenever it holds one:
/// these images don't change, so once fetched they're never asked for
/// again, even when the server's cache headers would have it revalidated.
/// Clearing DLsite's online cache in storage drops them.
///
/// Decoded images are also kept in memory: a lazy stack rebuilds a row that
/// scrolls back in, and a row whose image arrives a frame late first lays
/// out at the placeholder's height, shifting the page.
struct RemoteImage<Content: View, Placeholder: View>: View {
    let url: URL
    @ViewBuilder let content: (Image) -> Content
    @ViewBuilder let placeholder: () -> Placeholder

    @State private var image: UIImage?

    init(url: URL, @ViewBuilder content: @escaping (Image) -> Content, @ViewBuilder placeholder: @escaping () -> Placeholder) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
        _image = State(initialValue: RemoteImages.memory.object(forKey: url as NSURL))
    }

    var body: some View {
        Group {
            if let image { content(Image(uiImage: image)) } else { placeholder() }
        }
        .task(id: url) {
            if let cached = RemoteImages.memory.object(forKey: url as NSURL) { return image = cached }
            guard let loaded = await Self.load(url) else { return }
            let bitmap = loaded.cgImage!
            RemoteImages.memory.setObject(loaded, forKey: url as NSURL, cost: bitmap.bytesPerRow * bitmap.height)
            image = loaded
        }
    }

    /// Decoded off the main thread, ready to draw.
    @concurrent
    private static func load(_ url: URL) async -> UIImage? {
        do {
            let (data, _) = try await URLSession.shared.data(for: URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad))
            return await UIImage(data: data)?.byPreparingForDisplay()
        } catch {
            DiagnosticLog.shared.write("discover", "image_failed", ["url": url.absoluteString, "error": "\(error)"])
            return nil
        }
    }
}

enum RemoteImages {
    static let memory = {
        let cache = NSCache<NSURL, UIImage>()
        cache.totalCostLimit = 150_000_000
        return cache
    }()
}
