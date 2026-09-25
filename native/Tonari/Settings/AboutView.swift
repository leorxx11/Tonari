import SwiftUI
import TonariCore

/// Version, build and database schema.
struct AboutView: View {
    @Environment(\.appDatabase) private var database
    @State private var schemaVersion = 0

    static var version: String { Bundle.main.infoDictionary!["CFBundleShortVersionString"] as! String }
    static var build: String { Bundle.main.infoDictionary!["CFBundleVersion"] as! String }

    var body: some View {
        List {
            LabeledContent("版本", value: Self.version)
            LabeledContent("构建号", value: Self.build)
            LabeledContent("数据库版本", value: "\(schemaVersion)")
        }
        .navigationTitle("关于 Tonari")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            schemaVersion = try! database.reader.read { try Int.fetchOne($0, sql: "PRAGMA user_version")! }
        }
    }
}
