import SwiftUI
import TonariCore

/// Toggles which groups a work belongs to; new groups can be created inline.
struct CollectionPickerSheet: View {
    let work: Work

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
                    let member = !memberOf.contains(collection.id)
                    try! database.setMembership(work: work.productId, collection: collection.id, member: member)
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
                    let id = try! database.createCollection(named: name)
                    try! database.setMembership(work: work.productId, collection: id, member: true)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .task {
            await database.observe({ db in
                (
                    try LibraryCollection.order(Column("sort_order"), Column("created_at")).fetchAll(db),
                    try CollectionQueries.collectionIds(containing: work.productId, db)
                )
            }) {
                collections = $0.0
                memberOf = $0.1
            }
        }
    }
}
