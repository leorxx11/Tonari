import TonariCore

extension AppDatabase {
    /// Delivers `fetch` results now and after every change to the tables it
    /// read, until the calling task is cancelled (e.g. the view disappears).
    func observe<T: Sendable>(
        _ fetch: @escaping @Sendable (Database) throws -> T,
        update: (T) -> Void
    ) async {
        do {
            for try await value in ValueObservation.tracking(fetch).values(in: reader) {
                update(value)
            }
        } catch is CancellationError {
        } catch {
            fatalError("Database observation failed: \(error)")
        }
    }
}
