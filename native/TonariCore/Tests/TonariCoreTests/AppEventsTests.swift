import Foundation
import GRDB
import Testing
@testable import TonariCore

struct AppEventsTests {
    let database = try! AppDatabase.inMemory()

    @Test func repeatsBumpTheSameEntry() throws {
        try database.logEvent(category: "task", title: "导入失败", detail: "a", at: Date(timeIntervalSince1970: 10))
        try database.markEventsRead()
        try database.logEvent(category: "task", title: "导入失败", detail: "b", at: Date(timeIntervalSince1970: 20))
        try database.logEvent(category: "metadata", title: "资料补全失败", productId: "RJ01000001", action: .enrich)
        try database.logEvent(category: "metadata", title: "资料补全失败", productId: "RJ01000002", action: .enrich)

        let events = try database.reader.read(AppEvents.all)
        #expect(events.count == 3)
        let task = try #require(events.first { $0.category == "task" })
        #expect(task.count == 2 && task.detail == "b" && !task.read)
        #expect(task.lastAt == Date(timeIntervalSince1970: 20))
        #expect(try database.reader.read(AppEvents.unreadCount) == 3)

        try database.markEventsRead()
        #expect(try database.reader.read(AppEvents.unreadCount) == 0)
        try database.dismissEvent(task.id)
        #expect(try database.reader.read(AppEvents.all).count == 2)
        try database.clearEvents()
        #expect(try database.reader.read(AppEvents.all).isEmpty)
    }

    @Test func keepsTheNewestTwoHundred() throws {
        for index in 0..<(AppEvents.retained + 5) {
            try database.logEvent(category: "task", title: "失败 \(index)", at: Date(timeIntervalSince1970: Double(index)))
        }
        let events = try database.reader.read(AppEvents.all)
        #expect(events.count == AppEvents.retained)
        #expect(events.last?.title == "失败 5")
    }
}
