import Foundation
import GRDB
import Testing
@testable import TonariCore

struct WantedWorksTests {
    let database = try! AppDatabase.inMemory()

    private func wanted(_ id: String, at seconds: Double) -> WantedWork {
        WantedWork(productId: id, title: "作品 \(id)", circle: nil, coverUrl: "https://img/\(id).jpg", addedAt: Date(timeIntervalSince1970: seconds))
    }

    @Test func marksImportedAndClearsThem() throws {
        try database.addWanted(wanted("RJ1", at: 1))
        try database.addWanted(wanted("RJ2", at: 2))
        try database.writer.write { try Fixtures.work("RJ1").insert($0) }

        let entries = try database.reader.read(WantedWorks.all)
        #expect(entries.map(\.id) == ["RJ2", "RJ1"])
        #expect(entries.map(\.imported) == [false, true])

        try database.clearImportedWanted()
        #expect(try database.reader.read(WantedWorks.all).map(\.id) == ["RJ2"])
        try database.removeWanted("RJ2")
        #expect(try database.reader.read { try WantedWorks.contains("RJ2", $0) } == false)
    }
}
