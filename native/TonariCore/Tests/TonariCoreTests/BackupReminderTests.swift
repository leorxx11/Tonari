import Foundation
import Testing
@testable import TonariCore

struct BackupReminderTests {
    let database = try! AppDatabase.inMemory()
    let defaults = UserDefaults(suiteName: "BackupReminderTests.\(UUID().uuidString)")!
    let day: TimeInterval = 24 * 3600

    private func events() throws -> [AppEvent] {
        try database.reader.read(AppEvents.all)
    }

    @Test func remindsAtOnceWhenNeverBackedUp() throws {
        try database.remindBackupIfDue(defaults: defaults, now: Date(timeIntervalSince1970: 100 * day))
        let event = try #require(try events().first)
        #expect(event.title == "还没有备份过" && event.actionKey == "backup" && event.severity == "warning")
    }

    @Test func waitsThirtyDaysAfterABackup() throws {
        defaults.set(100 * day, forKey: BackupExport.lastExportedKey)
        try database.remindBackupIfDue(defaults: defaults, now: Date(timeIntervalSince1970: 129 * day))
        #expect(try events().isEmpty)
        try database.remindBackupIfDue(defaults: defaults, now: Date(timeIntervalSince1970: 130 * day))
        #expect(try events().map(\.title) == ["已超过 30 天没有备份"])
    }

    @Test func anIgnoredReminderReturnsAMonthLater() throws {
        defaults.set(100 * day, forKey: BackupExport.lastExportedKey)
        try database.remindBackupIfDue(defaults: defaults, now: Date(timeIntervalSince1970: 130 * day))
        try database.markEventsRead()
        try database.remindBackupIfDue(defaults: defaults, now: Date(timeIntervalSince1970: 159 * day))
        #expect(try database.reader.read(AppEvents.unreadCount) == 0)
        try database.remindBackupIfDue(defaults: defaults, now: Date(timeIntervalSince1970: 160 * day))
        let event = try #require(try events().first)
        #expect(event.count == 2 && !event.read)
    }
}
