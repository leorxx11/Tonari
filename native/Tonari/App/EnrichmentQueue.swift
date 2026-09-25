import Observation
import TonariCore

/// Background DLsite enrichment of works still missing metadata or covers,
/// one at a time. Each work gets two attempts per session so a permanently
/// failing fetch can't loop; the manual "补全" action resets that.
@Observable
final class EnrichmentQueue {
    let service: MetadataEnrichment
    private let database: AppDatabase

    private(set) var current: String?
    private(set) var done = 0
    private(set) var total = 0
    private var attempts: [String: Int] = [:]
    private var running = false

    private static let maxAttempts = 2

    var isActive: Bool { current != nil }

    init(database: AppDatabase) {
        self.database = database
        service = MetadataEnrichment(database: database, documents: .documentsDirectory)
    }

    /// Enriches every pending work, re-querying after each pass so works
    /// imported meanwhile are picked up too.
    func runPending(reset: Bool = false) async {
        if reset { attempts = [:] }
        guard !running else { return }
        running = true
        defer {
            running = false
            current = nil
        }
        while true {
            let pending = try! await database.reader.read { db in
                try Work.filter(Column("is_removed") == false).fetchAll(db)
            }
            .filter { MetadataEnrichment.needsEnrichment($0, documents: .documentsDirectory) && attempts[$0.productId, default: 0] < Self.maxAttempts }
            guard !pending.isEmpty else { return }
            total = pending.count
            for (index, work) in pending.enumerated() {
                let id = work.productId
                current = id
                done = index
                attempts[id, default: 0] += 1
                do {
                    try await service.enrich(id)
                } catch {
                    DiagnosticLog.shared.write("metadata", "enrich_failed", ["productId": id, "attempt": attempts[id]!, "error": "\(error)"])
                    if attempts[id]! >= Self.maxAttempts {
                        try! database.logEvent(
                            category: "metadata", title: "资料补全失败", detail: error.localizedDescription,
                            productId: id, workTitle: work.displayTitle, action: .enrich
                        )
                    }
                }
            }
        }
    }
}
