import Foundation
import Testing
@testable import TonariCore

struct CrashReportsTests {
    let reports = CrashReports(directory: URL.temporaryDirectory.appending(path: UUID().uuidString))

    @Test func listsNewestFirstWithKindAndTime() throws {
        #expect(try reports.all().isEmpty)
        try reports.save(Data("{\"a\":1}".utf8), kind: .crash, at: Date(timeIntervalSince1970: 10))
        try reports.save(Data("{\"b\":2}".utf8), kind: .hang, at: Date(timeIntervalSince1970: 20))
        try reports.save(Data("{\"c\":3}".utf8), kind: .hang, at: Date(timeIntervalSince1970: 20))

        let all = try reports.all()
        #expect(all.map(\.kind) == [.hang, .hang, .crash])
        #expect(all.last?.receivedAt == Date(timeIntervalSince1970: 10))
        #expect(try Data(contentsOf: all.last!.url) == Data("{\"a\":1}".utf8))

        try reports.delete(all[0])
        #expect(try reports.all().count == 2)
    }

    @Test func keepsTheNewestTwenty() throws {
        for index in 0..<(CrashReports.retained + 3) {
            try reports.save(Data("{}".utf8), kind: .crash, at: Date(timeIntervalSince1970: Double(index)))
        }
        let all = try reports.all()
        #expect(all.count == CrashReports.retained)
        #expect(all.last?.receivedAt == Date(timeIntervalSince1970: 3))
    }
}
