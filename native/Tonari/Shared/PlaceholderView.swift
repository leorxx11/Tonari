import SwiftUI

struct PlaceholderView: View {
    let title: String
    let systemImage: String
    let note: String

    var body: some View {
        NavigationStack {
            ContentUnavailableView(title, systemImage: systemImage, description: Text(note))
                .navigationTitle(title)
        }
    }
}
