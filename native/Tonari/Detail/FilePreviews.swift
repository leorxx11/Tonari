import SwiftUI
import TonariCore
import UIKit

/// What a subtitle preview shows: a track's matched subtitle from the
/// database, or a subtitle file no track claimed, parsed when opened.
enum SubtitlePreviewSource: Identifiable {
    case track(Track)
    case file(WorkFile, source: ImportedFolder?)

    var id: String {
        switch self {
        case .track(let track): "track:\(track.id)"
        case .file(let file, _): "file:\(file.id)"
        }
    }
}

/// A subtitle's lines in a half-height sheet. While its track plays, the
/// current line follows playback and tapping a line seeks; otherwise the
/// lines stay still and the header offers to play the track.
struct SubtitlePreviewSheet: View {
    let source: SubtitlePreviewSource

    @Environment(PlaybackController.self) private var player
    @Environment(\.appDatabase) private var database
    @State private var subtitle: Subtitle?
    @State private var fileLines: [Subtitle.Line] = []
    @State private var failure: String?
    @State private var showsTranslated = false
    @State private var holdUntil: Date?

    private var track: Track? {
        if case .track(let track) = source { track } else { nil }
    }

    private var isPlayingTrack: Bool {
        track.map { player.currentTrack?.id == $0.id } ?? false
    }

    /// Start time and text per line, the offset already applied.
    private var lines: [(startMs: Int, text: String)] {
        guard let subtitle else { return fileLines.map { ($0.startMs, $0.text) } }
        let texts = showsTranslated ? subtitle.translatedLinesJson! : subtitle.originalLinesJson
        return texts.indices.map { (subtitle.positionMs(ofLine: $0), texts[$0].text) }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if let failure {
                ContentUnavailableView("无法打开字幕", systemImage: "exclamationmark.triangle", description: Text(failure))
            } else {
                lineList
            }
            if let subtitle { footer(subtitle) }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .task { await load() }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline).lineLimit(1)
                Text("\(lines.count) 句").font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if let track, !isPlayingTrack {
                Button {
                    let queue = try! PlaybackStore(database: database).queue(for: track.workId, folder: track.folderPath)
                    player.play(queue, at: queue.tracks.firstIndex { $0.id == track.id }!)
                } label: {
                    Label("播放这首", systemImage: "play.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color(.systemBackground))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.primary, in: .capsule)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 12)
    }

    private var title: String {
        switch source {
        case .track(let track): track.titleZh.flatMap { $0.isEmpty ? nil : $0 } ?? track.title
        case .file(let file, _): file.fileName
        }
    }

    private var lineList: some View {
        let current = isPlayingTrack ? subtitle?.lineIndex(at: player.positionMs) : nil
        return ScrollViewReader { proxy in
            List {
                ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(Formatting.trackTime(ms: line.startMs))
                            .font(.footnote.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 52, alignment: .leading)
                        Text(line.text)
                            .fontWeight(index == current ? .semibold : .regular)
                            .foregroundStyle(current == nil || index == current ? .primary : .secondary)
                    }
                    .contentShape(.rect)
                    .onTapGesture {
                        guard isPlayingTrack else { return }
                        holdUntil = nil
                        player.seek(to: line.startMs)
                    }
                    .listRowBackground(index == current ? Color.accentColor.opacity(0.12) : nil)
                    .id(index)
                }
            }
            .listStyle(.plain)
            .onScrollPhaseChange { _, phase in
                if phase == .interacting {
                    holdUntil = .distantFuture
                } else if phase == .idle, holdUntil == .distantFuture {
                    holdUntil = .now.addingTimeInterval(3)
                }
            }
            .onChange(of: current) { _, current in
                guard let current, holdUntil.map({ Date.now > $0 }) ?? true else { return }
                withAnimation { proxy.scrollTo(current, anchor: UnitPoint(x: 0, y: 0.3)) }
            }
            .onAppear {
                if let current { proxy.scrollTo(current, anchor: UnitPoint(x: 0, y: 0.3)) }
            }
        }
    }

    private func footer(_ subtitle: Subtitle) -> some View {
        HStack(spacing: 12) {
            if subtitle.translatedLinesJson != nil {
                Picker("字幕语言", selection: $showsTranslated) {
                    Text("原文").tag(false)
                    Text("译文").tag(true)
                }
                .pickerStyle(.segmented)
                .frame(width: 140)
            }
            Spacer(minLength: 0)
            Button("提前 0.1 秒", systemImage: "minus") { shift(-100) }
                .labelStyle(.iconOnly)
            Menu {
                Button("重置字幕时间", systemImage: "arrow.counterclockwise") {
                    try! PlaybackStore(database: database).resetSubtitleOffset(of: subtitle.trackId)
                }
                .disabled(subtitle.timeOffsetMs == 0)
            } label: {
                Text("偏移 \(PlayerView.offsetText(subtitle.timeOffsetMs))")
                    .font(.subheadline.monospacedDigit())
            }
            Button("推后 0.1 秒", systemImage: "plus") { shift(100) }
                .labelStyle(.iconOnly)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.circle)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.bar)
    }

    private func shift(_ ms: Int) {
        try! PlaybackStore(database: database).shiftSubtitle(of: subtitle!.trackId, byMs: ms)
    }

    private func load() async {
        switch source {
        case .track(let track):
            await database.observe({ db in try Subtitle.fetchOne(db, key: track.id) }) { subtitle = $0 }
        case .file(let file, let folder):
            do {
                let text = TextDecoding.decode(try await WorkFileAccess.data(file, source: folder))
                fileLines = SubtitleParser.parse(text, format: (file.fileName as NSString).pathExtension)
            } catch {
                DiagnosticLog.shared.write("files", "subtitle_preview_failed", ["file": file.fileName, "error": "\(error)"])
                failure = error.localizedDescription
            }
        }
    }
}

/// A readme or script in full. UITextView lays out only what's on screen,
/// so a long script opens without stalling the main thread.
struct TextPreviewSheet: View {
    let file: WorkFile
    let source: ImportedFolder?

    @Environment(\.dismiss) private var dismiss
    @State private var text: String?
    @State private var failure: String?

    var body: some View {
        NavigationStack {
            Group {
                if let text {
                    ReadOnlyTextView(text: text)
                } else if let failure {
                    ContentUnavailableView("无法打开文件", systemImage: "exclamationmark.triangle", description: Text(failure))
                } else {
                    ProgressView()
                }
            }
            .navigationTitle(file.fileName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成", systemImage: "checkmark") { dismiss() }
                }
            }
        }
        .task {
            do {
                text = TextDecoding.decode(try await WorkFileAccess.data(file, source: source))
            } catch {
                DiagnosticLog.shared.write("files", "text_preview_failed", ["file": file.fileName, "error": "\(error)"])
                failure = error.localizedDescription
            }
        }
    }
}

private struct ReadOnlyTextView: UIViewRepresentable {
    let text: String

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.isEditable = false
        view.font = .preferredFont(forTextStyle: .body)
        view.adjustsFontForContentSizeCategory = true
        view.textContainerInset = UIEdgeInsets(top: 16, left: 12, bottom: 32, right: 12)
        view.text = text
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {}
}
