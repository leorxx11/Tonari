import SwiftUI
import TonariCore

/// What can be put in a group.
enum CollectionMember: Identifiable {
    case work(Work)
    case video(VideoItem)

    var id: String {
        switch self {
        case .work(let work): "work:\(work.productId)"
        case .video(let video): "video:\(video.id)"
        }
    }
}

/// Toggles which groups a work or video belongs to; new groups can be
/// created inline.
struct CollectionPickerSheet: View {
    let member: CollectionMember

    @Environment(\.appDatabase) private var database
    @Environment(\.dismiss) private var dismiss
    @State private var collections: [LibraryCollection] = []
    @State private var memberOf: Set<String> = []
    @State private var naming = false
    @State private var newName = ""

    var body: some View {
        NavigationStack {
            List(collections) { collection in
                Button {
                    setMembership(collection.id, !memberOf.contains(collection.id))
                } label: {
                    HStack {
                        Label(collection.name, systemImage: "folder")
                        Spacer()
                        if memberOf.contains(collection.id) {
                            Image(systemName: "checkmark").foregroundStyle(.tint)
                        }
                    }
                }
                .tint(.primary)
            }
            .overlay {
                if collections.isEmpty {
                    ContentUnavailableView("还没有分组", systemImage: "folder", description: Text("点右上角新建一个"))
                }
            }
            .navigationTitle("加入分组")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("新建分组", systemImage: "plus") { naming = true }
                }
            }
            .alert("新建分组", isPresented: $naming) {
                TextField("分组名称", text: $newName)
                Button("取消", role: .cancel) { newName = "" }
                Button("新建") {
                    let name = newName.trimmingCharacters(in: .whitespaces)
                    newName = ""
                    guard !name.isEmpty else { return }
                    setMembership(try! database.createCollection(named: name), true)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .task {
            await database.observe({ [member] db in
                (
                    try LibraryCollection.order(Column("sort_order"), Column("created_at")).fetchAll(db),
                    try {
                        switch member {
                        case .work(let work): try CollectionQueries.collectionIds(containing: work.productId, db)
                        case .video(let video): try CollectionQueries.collectionIds(containingVideo: video.id, db)
                        }
                    }()
                )
            }) {
                collections = $0.0
                memberOf = $0.1
            }
        }
    }

    private func setMembership(_ collectionId: String, _ isMember: Bool) {
        switch member {
        case .work(let work): try! database.setMembership(work: work.productId, collection: collectionId, member: isMember)
        case .video(let video): try! database.setMembership(video: video.id, collection: collectionId, member: isMember)
        }
    }
}
