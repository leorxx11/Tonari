import Foundation

extension RemoteImport {
    public static func p115(_ database: AppDatabase, client: P115Client = .shared) -> RemoteImport {
        RemoteImport(database: database, source: .p115(
            list: { try await client.list($0) },
            download: { try await client.download(pickcode: $0) }
        ))
    }
}

extension RemoteImport.Source {
    static func p115(
        list: @escaping @Sendable (String) async throws -> [RemoteEntry],
        download: @escaping @Sendable (String) async throws -> Data
    ) -> Self {
        Self(
            type: "p115", serverId: P115Client.sourceId, name: P115Client.sourceName, rootPath: "0",
            list: list, download: download,
            failure: { error in
                switch error as? P115Error {
                case .authExpired: .auth
                case .blocked: .unavailable
                default: nil
                }
            },
            categoryHint: p115CategoryHint
        )
    }

    /// The 115 build's own keyword rules, kept so rescans don't relabel tracks.
    static func p115CategoryHint(parent: String, file: String) -> String? {
        let s = "\(parent)/\(file)".lowercased()
        if s.contains("free") || s.contains("フリートーク") { return "free" }
        if s.contains("bonus") || s.contains("おまけ") || s.contains("特典") { return "bonus" }
        if s.contains("main") || s.contains("本編") || s.contains("本篇") { return "main" }
        return nil
    }
}
