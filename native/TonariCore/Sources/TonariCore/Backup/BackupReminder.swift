import Foundation

/// A monthly nudge toward a fresh backup: with sideloaded signing and no
/// sync, a backup is the only way the library survives a certificate change.
public enum BackupReminder {
    public static let remindedKey = "backup.remindedAt"
    static let interval: TimeInterval = 30 * 24 * 3600
}

extension AppDatabase {
    /// Logs the reminder unless a backup or an earlier reminder falls within
    /// the interval, so an ignored reminder comes back a month later.
    public func remindBackupIfDue(defaults: UserDefaults, now: Date = .now) throws {
        let exported = defaults.double(forKey: BackupExport.lastExportedKey)
        let latest = max(exported, defaults.double(forKey: BackupReminder.remindedKey))
        guard now.timeIntervalSince1970 - latest >= BackupReminder.interval else { return }
        try logEvent(
            category: "backup",
            severity: .warning,
            title: exported > 0 ? "已超过 30 天没有备份" : "还没有备份过",
            detail: "换证书或重装后，只能从备份恢复资料库。",
            action: .backup,
            at: now
        )
        defaults.set(now.timeIntervalSince1970, forKey: BackupReminder.remindedKey)
    }
}
