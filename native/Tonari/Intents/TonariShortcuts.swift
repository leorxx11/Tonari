import AppIntents

/// The intents offered without setup: in the Shortcuts app, to Siri and to
/// the Action button.
struct TonariShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ContinueListeningIntent(),
            phrases: ["用\(.applicationName)继续收听", "\(.applicationName)继续收听", "在\(.applicationName)继续播放"],
            shortTitle: "继续收听",
            systemImageName: "play.fill"
        )
        AppShortcut(
            intent: PlayWorkIntent(),
            phrases: ["用\(.applicationName)播放\(\.$work)", "用\(.applicationName)播放作品"],
            shortTitle: "播放作品",
            systemImageName: "music.note.list"
        )
        AppShortcut(
            intent: PlayRandomWorkIntent(),
            phrases: ["\(.applicationName)随机来一部", "用\(.applicationName)随机播放"],
            shortTitle: "随机播放",
            systemImageName: "shuffle"
        )
        AppShortcut(
            intent: SleepTimerIntent(),
            phrases: ["用\(.applicationName)设置睡眠定时", "\(.applicationName)睡眠定时\(\.$option)"],
            shortTitle: "睡眠定时",
            systemImageName: "moon.zzz"
        )
    }
}
