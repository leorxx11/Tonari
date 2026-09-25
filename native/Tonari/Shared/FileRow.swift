import SwiftUI

/// The files page and 115 browser row: a tinted type symbol, the name and a
/// detail line, with an optional trailing accessory.
struct FileRow<Accessory: View>: View {
    let icon: String
    let tint: Color
    let title: String
    let detail: String
    @ViewBuilder var accessory: Accessory

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.12), in: .rect(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline).lineLimit(3)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            accessory
        }
    }
}

extension FileRow where Accessory == EmptyView {
    init(icon: String, tint: Color, title: String, detail: String) {
        self.init(icon: icon, tint: tint, title: title, detail: detail) { EmptyView() }
    }
}

/// Symbol and color per file kind (`audio`, `subtitle`, ... or `folder`).
func fileIcon(_ kind: String) -> (String, Color) {
    switch kind {
    case "folder": ("folder.fill", .blue)
    case "audio": ("music.note", .pink)
    case "image": ("photo", .green)
    case "subtitle": ("captions.bubble", .cyan)
    case "text": ("doc.text", .orange)
    case "video": ("film", .purple)
    default: ("doc", .gray)
    }
}
