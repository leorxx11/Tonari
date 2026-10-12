import AppIntents
import TonariCore

/// Picks up what the mini player holds, where it was left; runs in the
/// background, so Siri and the Action button start it without opening Tonari.
struct ContinueListeningIntent: AudioPlaybackIntent {
    static let title: LocalizedStringResource = "继续收听"
    static let description = IntentDescription("从上次停下的地方接着播放。")

    @Dependency private var player: PlaybackController

    @MainActor func perform() async throws -> some IntentResult {
        guard player.hasCurrent else { throw IntentFailure.nothingPlayed }
        player.play()
        return .result()
    }
}

/// Plays a work as its page's play button does: where it was left, else
/// its track list from the start.
struct PlayWorkIntent: AudioPlaybackIntent {
    static let title: LocalizedStringResource = "播放作品"
    static let description = IntentDescription("播放资料库里的一部作品，听过的从上次停下的地方继续。")

    @Parameter(title: "作品")
    var work: WorkEntity

    @Dependency private var player: PlaybackController
    @Dependency private var database: AppDatabase

    static var parameterSummary: some ParameterSummary {
        Summary("播放\(\.$work)")
    }

    @MainActor func perform() async throws -> some IntentResult {
        let tracks = try await database.reader.read { [id = work.id] in try WorkQueries.tracks(of: id).fetchCount($0) }
        guard tracks > 0 else { throw IntentFailure.noAudio }
        player.playWork(work.id, database: database)
        return .result()
    }
}

struct PlayRandomWorkIntent: AudioPlaybackIntent {
    static let title: LocalizedStringResource = "随机播放"
    static let description = IntentDescription("随机挑一部有音频的作品，从头播放。")

    @Dependency private var player: PlaybackController
    @Dependency private var database: AppDatabase

    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let work = try await database.reader.read({ try WorkQueries.randomWithAudio($0) }) else {
            throw IntentFailure.emptyLibrary
        }
        let queue = try PlaybackStore(database: database).queue(for: work.productId, folder: Self.folder(of: work.productId, database))
        player.play(queue, at: 0)
        return .result(dialog: "正在播放《\(work.displayTitle)》")
    }

    @MainActor private static func folder(of productId: String, _ database: AppDatabase) -> [String] {
        let tracks = try! database.reader.read { try WorkQueries.tracks(of: productId).fetchAll($0) }
        let tree = WorkTree.build(tracks: tracks, files: [])
        return TrackFolderMemory.resolve(WorkTree.audioFolders(tree), tree: tree, productId: productId)!.path
    }
}

/// The player's own sleep timer choices.
enum SleepOption: String, AppEnum {
    case minutes15, minutes30, minutes45, minutes60, minutes90, endOfTrack, off

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "定时"
    static let caseDisplayRepresentations: [SleepOption: DisplayRepresentation] = [
        .minutes15: "15 分钟", .minutes30: "30 分钟", .minutes45: "45 分钟", .minutes60: "60 分钟", .minutes90: "90 分钟",
        .endOfTrack: "播完本曲", .off: "关闭定时",
    ]
}

struct SleepTimerIntent: AppIntent {
    static let title: LocalizedStringResource = "睡眠定时"
    static let description = IntentDescription("到时间后暂停正在播放的内容。")

    @Parameter(title: "定时", default: .minutes30)
    var option: SleepOption

    @Dependency private var player: PlaybackController

    static var parameterSummary: some ParameterSummary {
        Summary("睡眠定时\(\.$option)")
    }

    @MainActor func perform() async throws -> some IntentResult {
        let timer = player.sleep
        switch option {
        case .minutes15: timer.start(seconds: 15 * 60)
        case .minutes30: timer.start(seconds: 30 * 60)
        case .minutes45: timer.start(seconds: 45 * 60)
        case .minutes60: timer.start(seconds: 60 * 60)
        case .minutes90: timer.start(seconds: 90 * 60)
        case .endOfTrack: timer.stopAfter(tracks: 1)
        case .off: timer.cancel()
        }
        return .result()
    }
}

/// Opens a work's page.
struct OpenWorkIntent: OpenIntent {
    static let title: LocalizedStringResource = "打开作品"

    @Parameter(title: "作品")
    var target: WorkEntity

    @Dependency private var model: AppModel

    @MainActor func perform() async throws -> some IntentResult {
        model.openWork(target.id)
        return .result()
    }
}

enum IntentFailure: Error, CustomLocalizedStringResourceConvertible {
    case nothingPlayed, noAudio, emptyLibrary

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .nothingPlayed: "还没有播放记录"
        case .noAudio: "这部作品没有音频"
        case .emptyLibrary: "资料库里没有带音频的作品"
        }
    }
}
