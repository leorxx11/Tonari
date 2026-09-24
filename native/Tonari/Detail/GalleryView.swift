import SwiftUI
import UIKit

enum GalleryImage: Hashable {
    case local(String)
    case remote(URL)
}

struct GallerySelection: Identifiable {
    let images: [GalleryImage]
    let index: Int
    var id: Int { index }
}

/// Black full-screen pager; pinch or double-tap to zoom.
struct GalleryView: View {
    let selection: GallerySelection

    @Environment(\.dismiss) private var dismiss
    @State private var index: Int

    init(selection: GallerySelection) {
        self.selection = selection
        _index = State(initialValue: selection.index)
    }

    var body: some View {
        TabView(selection: $index) {
            ForEach(Array(selection.images.enumerated()), id: \.offset) { offset, image in
                ZoomableImage(image: image).tag(offset)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .background(.black)
        .ignoresSafeArea()
        .overlay(alignment: .top) {
            HStack {
                Text("\(index + 1) / \(selection.images.count)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.white)
                Spacer()
                Button("关闭", systemImage: "xmark") { dismiss() }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.glass)
            }
            .padding(.horizontal)
        }
        .statusBarHidden()
    }
}

private struct ZoomableImage: View {
    let image: GalleryImage

    @State private var uiImage: UIImage?
    @State private var failed = false
    @State private var scale: CGFloat = 1
    @State private var committedScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var committedOffset: CGSize = .zero

    var body: some View {
        ZStack {
            if let uiImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .offset(offset)
            } else if failed {
                Label("图片加载失败", systemImage: "exclamationmark.triangle").foregroundStyle(.white)
            } else {
                ProgressView().tint(.white)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(.rect)
        .gesture(MagnifyGesture()
            .onChanged { scale = max(1, committedScale * $0.magnification) }
            .onEnded { _ in
                committedScale = scale
                if scale == 1 { resetPan() }
            })
        .simultaneousGesture(scale > 1 ? DragGesture()
            .onChanged {
                offset = CGSize(
                    width: committedOffset.width + $0.translation.width,
                    height: committedOffset.height + $0.translation.height
                )
            }
            .onEnded { _ in committedOffset = offset } : nil)
        .onTapGesture(count: 2) {
            withAnimation(.snappy) {
                scale = scale > 1 ? 1 : 2.5
                committedScale = scale
                resetPan()
            }
        }
        .task {
            uiImage = await load()
            failed = uiImage == nil
        }
    }

    private func resetPan() {
        offset = .zero
        committedOffset = .zero
    }

    private func load() async -> UIImage? {
        switch image {
        case .local(let path):
            return UIImage(contentsOfFile: URL.documentsDirectory.appending(path: path).path)
        case .remote(let url):
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                return UIImage(data: data)
            } catch {
                return nil
            }
        }
    }
}
