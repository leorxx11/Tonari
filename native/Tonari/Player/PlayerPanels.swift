import SwiftUI
import TonariCore

/// Subtitles as Apple Music shows lyrics: the current line bright, the rest
/// dimmed, scrolling along with playback. Scrolling by hand pauses the
/// follow for a few seconds; tapping a line jumps there.
struct LyricsPanel: View {
    let subtitle: Subtitle?

    @Environment(PlaybackController.self) private var player
    @State private var holdUntil: Date?

    var body: some View {
        if let subtitle, !subtitle.originalLinesJson.isEmpty {
            let current = subtitle.lineIndex(at: player.positionMs)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 26) {
                        ForEach(Array(subtitle.originalLinesJson.enumerated()), id: \.offset) { index, line in
                            Text(line.text)
                                .font(.title2.bold())
                                .foregroundStyle(.primary)
                                .opacity(index == current ? 1 : 0.28)
                                .scaleEffect(index == current ? 1 : 0.97, anchor: .leading)
                                .animation(.spring(duration: 0.4), value: current)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(.rect)
                                .onTapGesture {
                                    holdUntil = nil
                                    player.seek(to: subtitle.positionMs(ofLine: index))
                                }
                                .id(index)
                        }
                    }
                    .padding(.vertical, 120)
                }
                .scrollIndicators(.hidden)
                .onScrollPhaseChange { _, phase in
                    if phase == .interacting {
                        holdUntil = .distantFuture
                    } else if phase == .idle, holdUntil == .distantFuture {
                        holdUntil = .now.addingTimeInterval(3)
                    }
                }
                .onChange(of: current) { _, current in
                    guard let current, holdUntil.map({ Date.now > $0 }) ?? true else { return }
                    withAnimation(.spring(duration: 0.6)) { proxy.scrollTo(current, anchor: UnitPoint(x: 0, y: 0.3)) }
                }
                .onAppear {
                    if let current { proxy.scrollTo(current, anchor: UnitPoint(x: 0, y: 0.3)) }
                }
            }
            .mask {
                LinearGradient(stops: [
                    .init(color: .clear, location: 0), .init(color: .black, location: 0.12),
                    .init(color: .black, location: 0.85), .init(color: .clear, location: 1),
                ], startPoint: .top, endPoint: .bottom)
            }
        } else {
            ContentUnavailableView("此音轨没有字幕", systemImage: "quote.bubble")
        }
    }
}

/// Apple Music's queue: playback options as capsules, then what plays next.
struct QueuePanel: View {
    @Binding var showingSleep: Bool
    @Environment(PlaybackController.self) private var player

    var body: some View {
        @Bindable var prefs = player.prefs
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                option("随机播放", symbol: "shuffle", active: prefs.mode == .shuffle) {
                    prefs.mode = prefs.mode == .shuffle ? .sequence : .shuffle
                }
                option(
                    prefs.mode == .loopOne ? "单曲循环" : "列表循环", symbol: prefs.mode == .loopOne ? "repeat.1" : "repeat",
                    active: prefs.mode == .loopAll || prefs.mode == .loopOne
                ) {
                    prefs.mode = switch prefs.mode {
                    case .loopAll: .loopOne
                    case .loopOne: .sequence
                    case .sequence, .shuffle: .loopAll
                    }
                }
                option("睡眠定时", symbol: player.sleep.isActive ? "moon.zzz.fill" : "moon.zzz", active: player.sleep.isActive) {
                    showingSleep = true
                }
                Menu {
                    Picker("播放速度", selection: Binding(get: { player.rate }, set: { player.setRate($0) })) {
                        ForEach(PlayerView.rates, id: \.self) { Text("\($0.formatted())x") }
                    }
                } label: {
                    capsule(active: player.rate != 1) {
                        Text("\(player.rate.formatted())x").font(.subheadline.weight(.semibold))
                    }
                }
            }
            .padding(.top, 18)
            VStack(alignment: .leading, spacing: 2) {
                Text("继续播放").font(.title3.bold())
                Text("来自 \(player.subtitle)").font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
            }
            .padding(.top, 20)
            .padding(.bottom, 8)
            let upcoming = Array(player.index + 1..<player.count)
            if upcoming.isEmpty {
                Text("已经是最后一首").foregroundStyle(.secondary).padding(.top, 12)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(upcoming, id: \.self) { index in
                            Button {
                                player.play(at: index)
                            } label: {
                                row(index)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
    }

    private func row(_ index: Int) -> some View {
        HStack(spacing: 12) {
            PlayerArtwork(path: player.work?.mainImageLocalPath, cornerRadius: 6)
                .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(player.title(at: index)).font(.body).lineLimit(1)
                let ms = player.durationMs(at: index)
                if ms > 0 {
                    Text(Formatting.trackTime(ms: ms)).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
        .contentShape(.rect)
    }

    private func option(_ title: String, symbol: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            capsule(active: active) {
                Image(systemName: symbol).font(.body.weight(.semibold)).contentTransition(.symbolEffect(.replace))
            }
        }
        .accessibilityLabel(title)
    }

    private func capsule(active: Bool, @ViewBuilder content: () -> some View) -> some View {
        content()
            .foregroundStyle(active ? Color.primary : .secondary)
            .frame(maxWidth: .infinity, minHeight: 36)
            .background(.primary.opacity(active ? 0.16 : 0.06), in: .capsule)
    }
}

struct SleepTimerSheet: View {
    @Environment(PlaybackController.self) private var player
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var prefs = player.prefs
        let sleep = player.sleep
        NavigationStack {
            List {
                if let status = sleep.statusText {
                    Section {
                        LabeledContent("当前", value: status)
                        Button("取消定时", role: .destructive) {
                            sleep.cancel()
                            dismiss()
                        }
                    }
                }
                Section {
                    ForEach(SleepTimer.presetMinutes, id: \.self) { minutes in
                        Button("\(minutes) 分钟") { start(seconds: minutes * 60) }
                    }
                    NavigationLink("自定义") { CustomSleepView(start: start) }
                } header: {
                    Text("按时间")
                } footer: {
                    Toggle("播完当前曲目再停止", isOn: $prefs.sleepFinishCurrentTrack)
                        // The list tints rows with the label color, which is white here.
                        .tint(.green)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .padding(.top, 4)
                }
                Section("按曲数") {
                    ForEach(SleepTimer.presetTrackCounts, id: \.self) { count in
                        Button(count == 1 ? "播完本曲" : "播完 \(count) 曲") {
                            sleep.stopAfter(tracks: count)
                            dismiss()
                        }
                    }
                }
            }
            .tint(.primary)
            .navigationTitle("睡眠定时")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func start(seconds: Int) {
        player.sleep.start(seconds: seconds)
        dismiss()
    }
}

private struct CustomSleepView: View {
    let start: (Int) -> Void
    @State private var hours = 0
    @State private var minutes = 30

    var body: some View {
        VStack {
            HStack(spacing: 0) {
                Picker("小时", selection: $hours) {
                    ForEach(0..<6) { Text("\($0) 小时") }
                }
                Picker("分钟", selection: $minutes) {
                    ForEach(0..<60) { Text("\($0) 分钟") }
                }
            }
            .pickerStyle(.wheel)
            Button("开始") { start(hours * 3600 + minutes * 60) }
                .buttonStyle(.borderedProminent)
                .disabled(hours == 0 && minutes == 0)
            Spacer()
        }
        .navigationTitle("自定义")
        .navigationBarTitleDisplayMode(.inline)
    }
}
