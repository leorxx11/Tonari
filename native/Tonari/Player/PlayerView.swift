import AVKit
import MediaPlayer
import SwiftUI
import TonariCore

/// The full-screen player, laid out after Apple Music. It zooms out of the
/// mini player and dragging it down shrinks it back in. Subtitles and the
/// queue replace the artwork in place, above controls that stay put.
struct PlayerView: View {
    enum Panel { case lyrics, queue }

    static let rates: [Float] = [0.75, 1, 1.25, 1.5, 2]

    @Environment(PlaybackController.self) private var player
    @Environment(AppModel.self) private var model
    @Environment(\.appDatabase) private var database
    @Environment(\.dismiss) private var dismiss
    @State private var panel: Panel?
    @State private var subtitle: Subtitle?
    @State private var showingSleep = false
    @Namespace private var artworkSpace

    var body: some View {
        ZStack {
            background
            if player.hasCurrent {
                VStack(spacing: 0) {
                    Capsule()
                        .fill(.tertiary)
                        .frame(width: 36, height: 5)
                        .padding(.top, 8)
                    if let panel {
                        compactHeader.padding(.top, 20)
                        Group {
                            switch panel {
                            case .lyrics: LyricsPanel(subtitle: subtitle)
                            case .queue: QueuePanel(showingSleep: $showingSleep)
                            }
                        }
                        .frame(maxHeight: .infinity)
                        .transition(.opacity)
                    } else {
                        Spacer(minLength: 16)
                        artwork
                            .aspectRatio(1, contentMode: .fit)
                            .shadow(color: .black.opacity(player.isPlaying ? 0.25 : 0.12), radius: player.isPlaying ? 24 : 12, y: 10)
                            .scaleEffect(player.isPlaying ? 1 : 0.84)
                            .animation(.spring(duration: 0.45, bounce: 0.25), value: player.isPlaying)
                        Spacer(minLength: 16)
                        HStack(spacing: 12) {
                            titles(font: .title3.bold())
                            Spacer(minLength: 0)
                            moreMenu
                        }
                    }
                    Scrubber().padding(.top, 16)
                    controls.padding(.top, 14)
                    VolumeRow().padding(.top, 22)
                    bottomBar.padding(.top, 22)
                }
                .padding(.horizontal, 28)
                // Sit the bottom row just above the home indicator, as Apple Music does.
                .padding(.bottom, 20)
                .ignoresSafeArea(edges: .bottom)
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingSleep) { SleepTimerSheet() }
        .onChange(of: player.hasCurrent) { _, hasCurrent in if !hasCurrent { dismiss() } }
        .task(id: player.currentTrack?.id) {
            guard let trackId = player.currentTrack?.id else {
                subtitle = nil
                return
            }
            await database.observe({ db in try Subtitle.fetchOne(db, key: trackId) }) { subtitle = $0 }
        }
    }

    /// Apple Music's dark, frosted grey tinted by the cover.
    private var background: some View {
        ZStack {
            Color(white: 0.2)
            if let path = player.work?.mainImageLocalPath {
                LocalImage(path: path).blur(radius: 60).opacity(0.85)
                Color.black.opacity(0.4)
            }
            LinearGradient(colors: [.white.opacity(0.06), .black.opacity(0.3)], startPoint: .top, endPoint: .bottom)
        }
        .ignoresSafeArea()
    }

    private var artwork: some View {
        PlayerArtwork(path: player.work?.mainImageLocalPath, cornerRadius: panel == nil ? 14 : 8)
            .matchedGeometryEffect(id: "artwork", in: artworkSpace)
    }

    private var compactHeader: some View {
        HStack(spacing: 14) {
            artwork
                .frame(width: 64, height: 64)
                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
            titles(font: .headline)
            Spacer(minLength: 0)
            moreMenu
        }
    }

    private func titles(font: Font) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(player.title).font(font).lineLimit(2)
            Text(subtitleLine).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
        }
    }

    private var subtitleLine: String {
        [player.subtitle, player.rate == 1 ? nil : "\(player.rate.formatted())x", player.sleep.statusText]
            .compactMap(\.self).joined(separator: " · ")
    }

    private var moreMenu: some View {
        Menu {
            Picker("播放速度", selection: Binding(get: { player.rate }, set: { player.setRate($0) })) {
                ForEach(Self.rates, id: \.self) { Text("\($0.formatted())x") }
            }
            .pickerStyle(.menu)
            if let subtitle {
                Section("字幕时间 · 当前 \(Self.offsetText(subtitle.timeOffsetMs))") {
                    Button("字幕提前 0.1 秒", systemImage: "backward") { shiftSubtitle(by: -100) }
                    Button("字幕推后 0.1 秒", systemImage: "forward") { shiftSubtitle(by: 100) }
                    if subtitle.timeOffsetMs != 0 {
                        Button("重置字幕时间", systemImage: "arrow.counterclockwise") {
                            try! PlaybackStore(database: database).resetSubtitleOffset(of: subtitle.trackId)
                        }
                    }
                }
            }
            if let work = player.work {
                Button("查看作品详情", systemImage: "info.circle") {
                    dismiss()
                    model.openWork(work.productId)
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.body.weight(.semibold))
                .frame(width: 32, height: 32)
                .background(.quaternary, in: .circle)
        }
        .tint(.primary)
    }

    private func shiftSubtitle(by delta: Int) {
        try! PlaybackStore(database: database).shiftSubtitle(of: subtitle!.trackId, byMs: delta)
    }

    static func offsetText(_ ms: Int) -> String {
        ms == 0 ? "0 秒" : String(format: "%+.1f 秒", Double(ms) / 1000)
    }

    private var controls: some View {
        let step = player.prefs.seekStep
        return HStack {
            Button("上一首", systemImage: "backward.fill", action: player.previous)
                .font(.title2)
                .disabled(!player.hasPrevious)
            Spacer()
            Button("后退 \(step) 秒", systemImage: Self.skipSymbol("gobackward", step)) { player.skip(seconds: -step) }
                .font(.title)
            Spacer()
            PlayPauseButton()
                .font(.system(size: 46))
                .frame(width: 64, height: 64)
            Spacer()
            Button("前进 \(step) 秒", systemImage: Self.skipSymbol("goforward", step)) { player.skip(seconds: step) }
                .font(.title)
            Spacer()
            Button("下一首", systemImage: "forward.fill", action: player.next)
                .font(.title2)
                .disabled(!player.hasNext)
        }
        .labelStyle(.iconOnly)
        .tint(.primary)
    }

    private var bottomBar: some View {
        HStack(alignment: .top) {
            panelButton(.lyrics, title: "字幕", symbol: "quote.bubble")
                .disabled(subtitle == nil)
            Spacer()
            RouteButton()
            Spacer()
            panelButton(.queue, title: "播放队列", symbol: "list.bullet")
        }
        .padding(.horizontal, 44)
        .frame(minHeight: 64, alignment: .top)
    }

    private func panelButton(_ target: Panel, title: String, symbol: String) -> some View {
        let active = panel == target
        return Button(title, systemImage: symbol) {
            withAnimation(.spring(duration: 0.45, bounce: 0.15)) { panel = active ? nil : target }
        }
        .labelStyle(.iconOnly)
        .font(.title3)
        .foregroundStyle(active ? Color.primary : .secondary)
        .frame(width: 44, height: 44)
        .background(active ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear), in: .circle)
    }

    /// SF Symbols has numbered skip glyphs for common steps only.
    static func skipSymbol(_ base: String, _ seconds: Int) -> String {
        [5, 10, 15, 30, 45, 60, 75, 90].contains(seconds) ? "\(base).\(seconds)" : base
    }
}

/// Apple Music's scrubber: a thick bar that grows while held and moves by
/// how far the finger travels rather than jumping to where it lands, so a
/// stray touch never seeks.
private struct Scrubber: View {
    @Environment(PlaybackController.self) private var player
    @State private var dragStart: Double?
    @State private var dragFraction: Double?

    var body: some View {
        let duration = player.durationMs
        let live = duration > 0 ? Double(min(player.positionMs, duration)) / Double(duration) : 0
        let fraction = dragFraction ?? live
        let shownMs = Int(fraction * Double(duration))
        VStack(spacing: 6) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(.primary.opacity(0.14))
                    Capsule()
                        .fill(.primary.opacity(dragFraction == nil ? 0.5 : 0.85))
                        .frame(width: proxy.size.width * fraction)
                }
                .frame(height: dragFraction == nil ? VolumeRow.barHeight : 12)
                .frame(maxHeight: .infinity)
                .contentShape(.rect)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let start = dragStart ?? live
                            dragStart = start
                            dragFraction = min(1, max(0, start + value.translation.width / proxy.size.width))
                        }
                        .onEnded { _ in
                            if let dragFraction, dragFraction != dragStart {
                                player.seek(to: Int(dragFraction * Double(duration)))
                            }
                            dragStart = nil
                            dragFraction = nil
                        }
                )
            }
            .frame(height: 24)
            .animation(.spring(duration: 0.25), value: dragFraction == nil)
            HStack {
                Text(Formatting.trackTime(ms: shownMs))
                Spacer()
                Text("-" + Formatting.trackTime(ms: max(0, duration - shownMs)))
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.secondary)
        }
        .disabled(duration == 0)
    }
}

/// System volume, in step with the hardware buttons, drawn as the same
/// thick bar as the scrubber through MPVolumeView's image hooks.
private struct VolumeRow: View {
    static let barHeight: CGFloat = 7

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "speaker.fill").font(.caption).foregroundStyle(.secondary)
            SystemVolumeSlider().frame(height: 34)
            Image(systemName: "speaker.wave.3.fill").font(.caption).foregroundStyle(.secondary)
        }
    }
}

private struct SystemVolumeSlider: UIViewRepresentable {
    final class BarVolumeView: MPVolumeView {
        override init(frame: CGRect) {
            super.init(frame: frame)
            // The player is always dark.
            setMinimumVolumeSliderImage(Self.bar(UIColor.white.withAlphaComponent(0.5)), for: .normal)
            setMaximumVolumeSliderImage(Self.bar(UIColor.white.withAlphaComponent(0.14)), for: .normal)
            // Invisible but finger-sized, so the bar has no knob yet stays easy to grab.
            setVolumeThumbImage(UIGraphicsImageRenderer(size: CGSize(width: 28, height: 28)).image { _ in }, for: .normal)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) is not used")
        }

        /// MPVolumeView pins its slider to the top of its bounds; center it
        /// so it lines up with the speaker icons.
        override func volumeSliderRect(forBounds bounds: CGRect) -> CGRect {
            let rect = super.volumeSliderRect(forBounds: bounds)
            return rect.offsetBy(dx: 0, dy: bounds.midY - rect.midY)
        }

        private static func bar(_ color: UIColor) -> UIImage {
            let height = VolumeRow.barHeight
            let size = CGSize(width: height * 2, height: height)
            return UIGraphicsImageRenderer(size: size).image { _ in
                color.setFill()
                UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: height / 2).fill()
            }
            .resizableImage(withCapInsets: UIEdgeInsets(top: 0, left: height / 2, bottom: 0, right: height / 2))
        }
    }

    func makeUIView(context: Context) -> BarVolumeView {
        BarVolumeView()
    }

    func updateUIView(_ view: BarVolumeView, context: Context) {}
}

/// The output device's own glyph and name, over a see-through system
/// route picker that opens the AirPlay menu.
private struct RouteButton: View {
    @Environment(PlaybackController.self) private var player

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                Image(systemName: player.route.symbol)
                    .font(.title3)
                    .foregroundStyle(player.route.name == nil ? .secondary : .primary)
                    .contentTransition(.symbolEffect(.replace))
                RoutePicker()
            }
            .frame(width: 44, height: 44)
            if let name = player.route.name {
                Text(name)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .fixedSize()
            }
        }
    }
}

private struct RoutePicker: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let view = AVRoutePickerView()
        view.tintColor = .clear
        view.activeTintColor = .clear
        return view
    }

    func updateUIView(_ view: AVRoutePickerView, context: Context) {}
}
