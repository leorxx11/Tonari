import Foundation

/// Circles, voice actors and tags across the visible library, each ranked by
/// how many works carry it.
public struct LibraryStats: Sendable, Equatable {
    public struct Entry: Sendable, Hashable {
        public let name: String
        public let count: Int
    }

    public let circles: [Entry]
    public let voiceActors: [Entry]
    public let genres: [Entry]

    public init(_ works: [Work]) {
        var circles: [String: Int] = [:]
        var voiceActors: [String: Int] = [:]
        var genres: [String: Int] = [:]
        func bump(_ counts: inout [String: Int], _ names: [String]) {
            for name in Set(names.map { $0.trimmingCharacters(in: .whitespaces) }) where !name.isEmpty {
                counts[name, default: 0] += 1
            }
        }
        for work in works {
            bump(&circles, [work.circleName].compactMap(\.self))
            bump(&voiceActors, work.voiceActors)
            bump(&genres, work.genreNames)
        }
        self.circles = Self.ranked(circles)
        self.voiceActors = Self.ranked(voiceActors)
        self.genres = Self.ranked(genres)
    }

    public func entries(for kind: WorkChip.Kind) -> [Entry] {
        switch kind {
        case .circle: circles
        case .voiceActor: voiceActors
        case .genre: genres
        case .series: []
        }
    }

    private static func ranked(_ counts: [String: Int]) -> [Entry] {
        counts.map { Entry(name: $0.key, count: $0.value) }
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0.name < $1.name }
    }
}
