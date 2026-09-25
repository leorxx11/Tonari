import MDKPlayer
import MetalKit
import SwiftUI

/// Draws the engine's frames with our own Metal device (mdk's foreign
/// context mode). Letting mdk manage a view or layer itself went wrong
/// both ways: a view got a layer sized in points but drawn in pixels, and a
/// layer got reframed from mdk's render thread every frame, which stalls
/// Core Animation and froze the picture. Here mdk only draws into the
/// drawable we hand it, on the main thread, once per display refresh while
/// the view runs (mdk holds a seek until the frame after it is drawn).
@MainActor
final class VideoRenderer: NSObject, MTKViewDelegate, MDKMetalTarget {
    let device = MTLCreateSystemDefaultDevice()!
    private let queue: MTLCommandQueue
    private unowned let engine: MDKPlayer
    /// The view on screen now; SwiftUI may replace it at any time.
    private weak var view: MTKView?
    private var surfaceSize: CGSize = .zero

    init(engine: MDKPlayer) {
        self.engine = engine
        queue = device.makeCommandQueue()!
        super.init()
        engine.setMetalRenderer(device: device, queue: queue, target: self)
    }

    /// Stops drawing while nothing moves; seeks and new videos resume it.
    var isRunning = true {
        didSet { view?.isPaused = !isRunning }
    }

    /// mdk asks from inside `renderVideo()`, which runs in `draw(in:)` on
    /// the main thread.
    nonisolated var currentTexture: AnyObject? {
        MainActor.assumeIsolated { Texture(value: view?.currentDrawable?.texture) }.value
    }

    nonisolated private struct Texture: @unchecked Sendable {
        let value: AnyObject?
    }

    func makeView() -> MTKView {
        let view = MTKView(frame: .zero, device: device)
        view.colorPixelFormat = .bgra8Unorm
        view.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        view.backgroundColor = .black
        view.preferredFramesPerSecond = 60
        view.isPaused = !isRunning
        view.delegate = self
        self.view = view
        return view
    }

    nonisolated func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    nonisolated func draw(in view: MTKView) {
        MainActor.assumeIsolated {
            guard self.view === view else { return }
            let size = view.drawableSize
            guard size.width > 0, size.height > 0 else { return }
            if size != surfaceSize {
                surfaceSize = size
                engine.setVideoSurfaceSize(width: Int32(size.width), height: Int32(size.height))
            }
            guard let drawable = view.currentDrawable else { return }
            engine.renderVideo()
            let buffer = queue.makeCommandBuffer()!
            buffer.present(drawable)
            buffer.commit()
        }
    }
}

struct VideoSurface: UIViewRepresentable {
    let renderer: VideoRenderer

    func makeUIView(context: Context) -> MTKView {
        renderer.makeView()
    }

    func updateUIView(_ view: MTKView, context: Context) {}
}
