import MDKPlayer
import SwiftUI
import TonariCore

/// Full-screen video on black, the picture centered at its own ratio, with
/// glass controls that hide after three idle seconds. Sliding sideways
/// scrubs (the jump happens on release), double-tapping either half skips,
/// and dragging down shrinks the player back into the mini player.
struct VideoPlayerView: View {
    @Environment(VideoController.self) private var video
    @Environment(PlaybackController.self) private var audio
    @Environment(\.dismiss) private var dismiss
    @State private var controlsVisible = true
    @State private var hideTask: Task<Void, Never>?
    @State private var locked = false
    /// Where a sideways slide would land, shown until release.
    @State private var scrubTarget: Int?
    @State private var scrubStart: Int?
    @State private var showingSleep = false
    @State private var skipFlash: SkipFlash?

    private struct SkipFlash: Equatable {
        let forward: Bool
        let id = UUID()
    }

    /// A full-width slide moves this far.
    private static let scrubSpanMs = 90_000

    private var step: Int { audio.prefs.seekStep }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black
                picture
                gestureLayer(width: proxy.size.width)
                if let skipFlash {
                    skipBadge(skipFlash).transition(.opacity)
                }
                if let scrubTarget {
                    scrubBadge(scrubTarget)
                }
                if locked {
                    if controlsVisible { unlockButton }
                } else if controlsVisible {
                    controls.transition(.opacity)
                }
            }
            .ignoresSafeArea()
        }
        .preferredColorScheme(.dark)
        .statusBarHidden(!controlsVisible)
        .persistentSystemOverlays(controlsVisible ? .automatic : .hidden)
        .interactiveDismissDisabled(locked)
        .sheet(isPresented: $showingSleep) { SleepTimerSheet() }
        .onAppear {
            AppDelegate.allow(.allButUpsideDown, turningTo: .portrait)
            scheduleHide()
        }
        .onDisappear { AppDelegate.allow(.portrait, turningTo: .portrait) }
        .onChange(of: video.hasCurrent) { _, hasCurrent in if !hasCurrent { dismiss() } }
    }

    // MARK: - Picture and gestures

    @ViewBuilder private var picture: some View {
        if let renderer = video.renderer {
            VideoSurface(renderer: renderer)
                .id(ObjectIdentifier(renderer))
                .aspectRatio(video.videoSize.map { $0.width / $0.height } ?? 16 / 9, contentMode: .fit)
        }
    }

    private func gestureLayer(width: CGFloat) -> some View {
        Color.clear
            .contentShape(.rect)
            .gesture(
                SpatialTapGesture(count: 2)
                    .onEnded { value in
                        guard !locked else { return }
                        let forward = value.location.x > width / 2
                        video.skip(seconds: forward ? step : -step)
                        withAnimation(.easeOut(duration: 0.15)) { skipFlash = SkipFlash(forward: forward) }
                        let flash = skipFlash
                        Task {
                            try? await Task.sleep(for: .milliseconds(600))
                            if skipFlash == flash { withAnimation { skipFlash = nil } }
                        }
                    }
                    .exclusively(before: TapGesture().onEnded { toggleControls() })
            )
            .simultaneousGesture(
                DragGesture(minimumDistance: 14)
                    .onChanged { value in
                        guard !locked, video.durationMs > 0 else { return }
                        // Sideways only; a downward drag belongs to dismissing.
                        if scrubStart == nil {
                            guard abs(value.translation.width) > abs(value.translation.height) else { return }
                            scrubStart = video.positionMs
                        }
                        let delta = Int(value.translation.width / width * Double(Self.scrubSpanMs))
                        scrubTarget = min(video.durationMs, max(0, scrubStart! + delta))
                    }
                    .onEnded { _ in
                        if let scrubTarget { video.seek(to: scrubTarget) }
                        scrubStart = nil
                        scrubTarget = nil
                    }
            )
    }

    private func scrubBadge(_ target: Int) -> some View {
        let delta = target - (scrubStart ?? target)
        let sign = delta < 0 ? "-" : "+"
        return Text("\(sign)\(Formatting.trackTime(ms: abs(delta))) · \(Formatting.trackTime(ms: target))")
            .font(.title3.monospacedDigit().weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .glassEffect(.regular, in: .capsule)
    }

    private func skipBadge(_ flash: SkipFlash) -> some View {
        HStack {
            if flash.forward { Spacer() }
            Label("\(step) 秒", systemImage: flash.forward ? "goforward" : "gobackward")
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .glassEffect(.regular, in: .capsule)
            if !flash.forward { Spacer() }
        }
        .padding(.horizontal, 48)
    }

    // MARK: - Controls

    private var controls: some View {
        VStack(spacing: 0) {
            topBar
            Spacer()
            centerButtons
            Spacer()
            bottomBar
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .safeAreaPadding(.vertical, 44)
        .background {
            LinearGradient(
                stops: [.init(color: .black.opacity(0.55), location: 0), .init(color: .clear, location: 0.25),
                        .init(color: .clear, location: 0.7), .init(color: .black.opacity(0.6), location: 1)],
                startPoint: .top, endPoint: .bottom
            )
            .allowsHitTesting(false)
        }
        // Touching any control keeps them up a little longer.
        .simultaneousGesture(TapGesture().onEnded { scheduleHide() })
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            glassButton("收起", systemImage: "chevron.down") { dismiss() }
            Text(video.title)
                .font(.headline)
                .foregroundStyle(.white)
                .lineLimit(2)
            Spacer(minLength: 0)
            ZStack {
                Image(systemName: "airplay.video").font(.body.weight(.semibold)).foregroundStyle(.white)
                RoutePicker()
            }
            .frame(width: 44, height: 44)
            .glassEffect(.regular.interactive(), in: .circle)
        }
    }

    private var centerButtons: some View {
        HStack(spacing: 44) {
            glassButton("后退 \(step) 秒", systemImage: PlayerView.skipSymbol("gobackward", step), size: 56) {
                video.skip(seconds: -step)
            }
            Button {
                video.togglePlay()
                scheduleHide()
            } label: {
                Group {
                    // Until the video is ready the middle button only says so.
                    if video.isLoading {
                        ProgressView().tint(.white).controlSize(.large)
                    } else {
                        Image(systemName: video.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 34, weight: .semibold))
                            .contentTransition(.symbolEffect(.replace))
                    }
                }
                .foregroundStyle(.white)
                .frame(width: 80, height: 80)
            }
            .buttonStyle(.plain)
            .disabled(video.isLoading)
            .glassEffect(.regular.interactive(), in: .circle)
            .accessibilityLabel(video.isPlaying ? "暂停" : "播放")
            glassButton("前进 \(step) 秒", systemImage: PlayerView.skipSymbol("goforward", step), size: 56) {
                video.skip(seconds: step)
            }
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 10) {
            VideoScrubber()
            HStack(spacing: 12) {
                glassButton("睡眠定时", systemImage: audio.sleep.isActive ? "moon.zzz.fill" : "moon.zzz") { showingSleep = true }
                Menu {
                    Picker("播放速度", selection: Binding(get: { video.rate }, set: { video.setRate($0) })) {
                        ForEach(PlayerView.rates, id: \.self) { Text("\($0.formatted())x") }
                    }
                } label: {
                    Text("\(video.rate.formatted())x")
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.white)
                        .frame(minWidth: 44, minHeight: 44)
                        .padding(.horizontal, 4)
                }
                .glassEffect(.regular.interactive(), in: .capsule)
                Spacer()
                glassButton("锁定", systemImage: "lock.open") {
                    withAnimation { locked = true }
                    scheduleHide()
                }
                glassButton("旋转", systemImage: "rotate.right", action: rotate)
            }
        }
    }

    private var unlockButton: some View {
        VStack {
            Spacer()
            glassButton("解锁", systemImage: "lock.fill", size: 56) {
                withAnimation { locked = false }
                scheduleHide()
            }
            .padding(.bottom, 60)
        }
    }

    private func glassButton(_ title: String, systemImage: String, size: CGFloat = 44, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(size > 44 ? .title2 : .body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel(title)
    }

    // MARK: - Behaviour

    private func toggleControls() {
        withAnimation(.easeInOut(duration: 0.2)) { controlsVisible.toggle() }
        if controlsVisible { scheduleHide() }
    }

    private func scheduleHide() {
        hideTask?.cancel()
        hideTask = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled, video.isPlaying || locked else { return }
            withAnimation(.easeInOut(duration: 0.3)) { controlsVisible = false }
        }
    }

    private func rotate() {
        let scene = UIApplication.shared.connectedScenes.first as! UIWindowScene
        let landscape = scene.effectiveGeometry.interfaceOrientation.isLandscape
        AppDelegate.allow(.allButUpsideDown, turningTo: landscape ? .portrait : .landscapeRight)
        scheduleHide()
    }
}

/// Reads the video clock itself, so only the bar redraws as it ticks.
private struct VideoScrubber: View {
    @Environment(VideoController.self) private var video

    var body: some View {
        Scrubber(positionMs: video.positionMs, durationMs: video.durationMs) { video.seek(to: $0) }
            .foregroundStyle(.white)
    }
}
