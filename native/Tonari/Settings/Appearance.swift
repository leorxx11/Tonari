import SwiftUI

/// Light, dark or following the system, stored like the Flutter build.
enum Appearance: String, CaseIterable {
    case system, light, dark

    static let preferenceKey = "theme.mode"

    var label: String {
        switch self {
        case .system: "跟随系统"
        case .light: "浅色"
        case .dark: "深色"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
