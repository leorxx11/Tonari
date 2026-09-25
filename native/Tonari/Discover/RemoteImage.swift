import SwiftUI
import TonariCore
import UIKit

/// A DLsite or chobit image, from the URL cache whenever it holds one:
/// these images don't change, so once fetched they're never asked for
/// again, even when the server's cache headers would have it revalidated.
/// Clearing DLsite's online cache in storage drops them.
struct RemoteImage<Content: View, Placeholder: View>: View {
    let url: URL
    @ViewBuilder let content: (Image) -> Content
    @ViewBuilder let placeholder: () -> Placeholder

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image { content(Image(uiImage: image)) } else { placeholder() }
        }
        .task(id: url) { image = await Self.load(url) }
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
