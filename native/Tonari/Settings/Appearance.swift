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

    var systemImage: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max"
        case .dark: "moon"
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

struct AppearanceSettingsView: View {
    @AppStorage(Appearance.preferenceKey) private var appearance = Appearance.system

    var body: some View {
        List {
            Section {
                Picker("主题", selection: $appearance) {
                    ForEach(Appearance.allCases, id: \.self) { Label($0.label, systemImage: $0.systemImage) }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
        }
        .navigationTitle("外观")
        .navigationBarTitleDisplayMode(.inline)
    }
}
