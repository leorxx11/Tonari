import SwiftUI

extension Color {
    /// The vermilion of the app icon's seal.
    static let seal = Color(red: 0.878, green: 0.294, blue: 0.251)
    static let sealDeep = Color(red: 0.639, green: 0.133, blue: 0.114)
    /// The cream of the seal's glyph.
    static let sealInk = Color(red: 0.969, green: 0.914, blue: 0.784)
}

extension ShapeStyle where Self == LinearGradient {
    static var seal: LinearGradient {
        LinearGradient(colors: [.seal, .sealDeep], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}
