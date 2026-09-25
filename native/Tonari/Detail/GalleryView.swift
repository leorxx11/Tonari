import SwiftUI
import TonariCore
import UIKit

enum GalleryImage: Hashable {
    case local(String)
    /// A work's bundled image or one met while browsing 115.
    case file(PreviewFile)

    /// Also the zoom transition's source id: whatever shows this image on
    /// the page underneath marks itself with it.
    var id: String {
        switch self {
        case .local(let path): path
        case .file(let file): file.id
        }
    }
}

struct GallerySelection: Identifiable {
    let images: [GalleryImage]
    let index: Int
    /// Keeps the page underneath on the same image, so closing shrinks back
    /// into something on screen (the detail cover pager).
    var follow: ((Int) -> Void)?
    var id: Int { index }
}

/// Full-screen pager after Photos: zooms out of the tapped image and back
/// into it when dragged down; tap hides the chrome, pinch or double-tap
/// zooms, and a zoomed image pans instead of closing.
struct GalleryView: View {
    let selection: GallerySelection
    let namespace: Namespace.ID

    @Environment(\.dismiss) private var dismiss
    @State private var index: Int
    @State private var showsChrome = true
    @State private var zoomed = false

    init(selection: GallerySelection, namespace: Namespace.ID) {
        self.selection = selection
        self.namespace = namespace
        _index = State(initialValue: selection.index)
    }

    var body: some View {
        TabView(selection: $index) {
            ForEach(Array(selection.images.enumerated()), id: \.offset) { offset, image in
                ZoomableImage(image: image, zoomed: $zoomed) {
                    withAnimation(.easeInOut(duration: 0.2)) { showsChrome.toggle() }
                }
                .tag(offset)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .background(.black)
        .ignoresSafeArea()
        .overlay(alignment: .top) {
            if showsChrome {
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
                .transition(.opacity)
            }
        }
        .statusBarHidden()
        .interactiveDismissDisabled(zoomed)
        .onChange(of: index) { _, index in
            zoomed = false
            selection.follow?(index)
        }
        .navigationTransition(.zoom(sourceID: selection.images[index].id, in: namespace))
    }
}

private struct ZoomableImage: View {
    let image: GalleryImage
    @Binding var zoomed: Bool
    let toggleChrome: () -> Void

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
                zoomed = scale > 1
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
                zoomed = scale > 1
                resetPan()
            }
        }
        .onTapGesture(perform: toggleChrome)
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
        case .file(let file):
            do {
                return UIImage(data: try await file.data())
            } catch {
                DiagnosticLog.shared.write("files", "image_load_failed", ["file": file.name, "error": "\(error)"])
                return nil
            }
        }
    }
}
