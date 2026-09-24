import Foundation

/// What the search tab shows for a query: matching works, and the voice
/// actors, circles and tags whose names match, each with its work count.
public struct LibrarySearch: Sendable, Equatable {
    public let works: [Work]
    public let voiceActors: [LibraryStats.Entry]
    public let circles: [LibraryStats.Entry]
    public let genres: [LibraryStats.Entry]

    public var isEmpty: Bool { works.isEmpty && voiceActors.isEmpty && circles.isEmpty && genres.isEmpty }

    /// `#tag` narrows both works and names to tags.
    public init(_ query: String, works: [Work], stats: LibraryStats) {
        let trimmed = query.trimmingCharacters(in: .whitespaces).lowercased()
        let tagOnly = trimmed.hasPrefix("#")
        let needle = tagOnly ? trimmed.dropFirst().trimmingCharacters(in: .whitespaces) : trimmed
        func names(_ entries: [LibraryStats.Entry]) -> [LibraryStats.Entry] {
            needle.isEmpty ? [] : entries.filter { $0.name.lowercased().contains(needle) }
        }
        self.works = works.filter { $0.matches(search: trimmed) }
        voiceActors = tagOnly ? [] : names(stats.voiceActors)
        circles = tagOnly ? [] : names(stats.circles)
        genres = names(stats.genres)
    }
}
