import AVKit
import SwiftUI
import TonariCore

/// Keeps the current subtitle line on screen over other apps in a system
/// Picture in Picture window. PiP only shows video, so each line is painted
/// into a frame and fed to a sample-buffer layer; its play button drives
/// the audio player.
@Observable
final class SubtitlePiP: NSObject {
    static var isSupported: Bool { AVPictureInPictureController.isPictureInPictureSupported() }

    /// On from the user's tap until the window closes.
    private(set) var isActive = false

    @ObservationIgnored let layer = AVSampleBufferDisplayLayer()
    @ObservationIgnored weak var player: PlaybackController?
    @ObservationIgnored private let database: AppDatabase
    @ObservationIgnored private var controller: AVPictureInPictureController!
    @ObservationIgnored private var possibleObservation: NSKeyValueObservation?
    @ObservationIgnored private var subtitle: Subtitle?
    @ObservationIgnored private var subtitleTrackId: String?
    @ObservationIgnored private var subtitleTask: Task<Void, Never>?
    @ObservationIgnored private var shownText: String?
    @ObservationIgnored private var positionMs = 0
    /// Mirrored from the player: AVKit asks for it while the PiP controller
    /// is still being created, before the player is wired up.
    @ObservationIgnored private var isPlaying = false

    // A wide strip, so the window sits on screen like a caption bar.
    private static let canvasWidth = 700
    private static let canvasHeight = 100

    init(database: AppDatabase) {
        self.database = database
        super.init()
        layer.videoGravity = .resizeAspect
        controller = AVPictureInPictureController(contentSource: .init(sampleBufferDisplayLayer: layer, playbackDelegate: self))
        controller.delegate = self
        NotificationCenter.default.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                // Coming back from the background can leave the layer failed;
                // repaint so the window isn't stuck on a dead frame.
                guard let self, self.isActive, let text = self.shownText else { return }
                self.render(text)
            }
        }
    }

    func start(trackId: String?, positionMs: Int) {
        isActive = true
        shownText = nil
        update(trackId: trackId, positionMs: positionMs)
        // PiP won't start before a frame is in; wait until AVKit says it can.
        possibleObservation = controller.observe(\.isPictureInPicturePossible, options: [.initial, .new]) { [weak self] controller, _ in
            guard controller.isPictureInPicturePossible else { return }
            Task { @MainActor in
                guard let self, self.possibleObservation != nil else { return }
                self.possibleObservation = nil
                self.controller.startPictureInPicture()
            }
        }
        DiagnosticLog.shared.write("subtitle_pip", "start_requested")
    }

    func stop() {
        possibleObservation = nil
        controller.stopPictureInPicture()
        isActive = false
    }

    /// Called as playback moves; repaints only when the line changes.
    func update(trackId: String?, positionMs: Int) {
        guard isActive else { return }
        self.positionMs = positionMs
        if trackId != subtitleTrackId { observeSubtitle(of: trackId) }
        repaint()
    }

    private func repaint() {
        let text = subtitle.flatMap { subtitle in subtitle.lineIndex(at: positionMs).map { subtitle.originalLinesJson[$0].text } } ?? ""
        guard text != shownText else { return }
        shownText = text
        render(text)
    }

    func playbackStateChanged(isPlaying: Bool) {
        self.isPlaying = isPlaying
        controller.invalidatePlaybackState()
    }

    private func observeSubtitle(of trackId: String?) {
        subtitleTask?.cancel()
        subtitleTrackId = trackId
        subtitle = nil
        guard let trackId else { return }
        subtitleTask = Task { [weak self, database] in
            await database.observe({ db in try Subtitle.fetchOne(db, key: trackId) }) { subtitle in
                // Repaint now for the first load or a new offset, even while paused.
                self?.subtitle = subtitle
                self?.repaint()
            }
        }
    }

    // MARK: - Painting

    /// White text centered on black; long lines wrap and shrink to fit the
    /// strip instead of resizing the window.
    private func render(_ text: String) {
        let width = Self.canvasWidth, height = Self.canvasHeight
        var created: CVPixelBuffer?
        CVPixelBufferCreate(
            kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA,
            // PiP drops frames that aren't IOSurface backed.
            [kCVPixelBufferIOSurfacePropertiesKey: [:]] as CFDictionary, &created
        )
        let buffer = created!
        CVPixelBufferLockBaseAddress(buffer, [])
        let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer), width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer), space: CGColorSpaceCreateDeviceRGB(),
            // 32BGRA in memory is ARGB little-endian with the alpha byte unused.
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        )!
        context.setFillColor(UIColor.black.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        UIGraphicsPushContext(context)
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
        let inset: CGFloat = 16
        let drawWidth = CGFloat(width) - inset * 2
        let maxHeight = CGFloat(height) - 12
        var fontSize: CGFloat = 32
        var line = Self.attributed(text, fontSize: fontSize)
        var textHeight = Self.height(of: line, width: drawWidth)
        while textHeight > maxHeight && fontSize > 20 {
            fontSize -= 2
            line = Self.attributed(text, fontSize: fontSize)
            textHeight = Self.height(of: line, width: drawWidth)
        }
        let drawHeight = min(textHeight, maxHeight)
        line.draw(
            with: CGRect(x: inset, y: (CGFloat(height) - drawHeight) / 2, width: drawWidth, height: drawHeight),
            options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine], context: nil
        )
        UIGraphicsPopContext()
        CVPixelBufferUnlockBaseAddress(buffer, [])

        let format = try! CMVideoFormatDescription(imageBuffer: buffer)
        let timing = CMSampleTimingInfo(duration: .invalid, presentationTimeStamp: CMClockGetTime(CMClockGetHostTimeClock()), decodeTimeStamp: .invalid)
        let sample = try! CMSampleBuffer(imageBuffer: buffer, formatDescription: format, sampleTiming: timing)
        sample.sampleAttachments[0][.displayImmediately] = true
        let renderer = layer.sampleBufferRenderer
        if renderer.status == .failed { renderer.flush() }
        renderer.enqueue(sample)
    }

    private static func attributed(_ text: String, fontSize: CGFloat) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byWordWrapping
        return NSAttributedString(string: text, attributes: [
            .font: UIFont.systemFont(ofSize: fontSize, weight: .semibold),
            .foregroundColor: UIColor.white,
            .paragraphStyle: paragraph,
        ])
    }

    private static func height(of text: NSAttributedString, width: CGFloat) -> CGFloat {
        ceil(text.boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin], context: nil).height)
    }
}

extension SubtitlePiP: AVPictureInPictureSampleBufferPlaybackDelegate {
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, setPlaying playing: Bool) {
        playing ? player!.play() : player!.pause()
    }

    /// A live range: the window has no timeline to scrub.
    func pictureInPictureControllerTimeRangeForPlayback(_ pictureInPictureController: AVPictureInPictureController) -> CMTimeRange {
        CMTimeRange(start: .negativeInfinity, duration: .positiveInfinity)
    }

    func pictureInPictureControllerIsPlaybackPaused(_ pictureInPictureController: AVPictureInPictureController) -> Bool {
        !isPlaying
    }

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, didTransitionToRenderSize newRenderSize: CMVideoDimensions) {}

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, skipByInterval skipInterval: CMTime) async {}
}

extension SubtitlePiP: AVPictureInPictureControllerDelegate {
    func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        DiagnosticLog.shared.write("subtitle_pip", "started")
    }

    func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        DiagnosticLog.shared.write("subtitle_pip", "stopped")
        isActive = false
    }

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
        DiagnosticLog.shared.write("subtitle_pip", "start_failed", ["error": "\(error)"])
        isActive = false
    }
}

/// PiP needs its layer in the window; a near-invisible pixel carries it.
struct SubtitlePiPHost: UIViewRepresentable {
    let pip: SubtitlePiP

    final class HostView: UIView {
        override func layoutSubviews() {
            super.layoutSubviews()
            layer.sublayers?.forEach { $0.frame = bounds }
        }
    }

    func makeUIView(context: Context) -> HostView {
        let view = HostView()
        view.isUserInteractionEnabled = false
        view.alpha = 0.01
        view.layer.addSublayer(pip.layer)
        return view
    }

    func updateUIView(_ view: HostView, context: Context) {}
}
