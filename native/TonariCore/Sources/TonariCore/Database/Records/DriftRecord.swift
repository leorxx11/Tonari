import Foundation
import GRDB

/// Row type of a table inherited from the Flutter build's Drift schema:
/// snake_case columns, dates as whole Unix seconds, and nested values (string
/// lists, `*_json` columns) as JSON text written like Dart's `jsonEncode`.
public protocol DriftRecord: Codable, Sendable, FetchableRecord, PersistableRecord {}

extension DriftRecord {
    public static var databaseColumnDecodingStrategy: DatabaseColumnDecodingStrategy { .convertFromSnakeCase }
    public static var databaseColumnEncodingStrategy: DatabaseColumnEncodingStrategy { .convertToSnakeCase }

    public static func databaseDateDecodingStrategy(for column: String) -> DatabaseDateDecodingStrategy {
        .timeIntervalSince1970
    }

    public static func databaseDateEncodingStrategy(for column: String) -> DatabaseDateEncodingStrategy {
        .secondsSince1970
    }

    public static func databaseJSONEncoder(for column: String) -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return encoder
    }
}
