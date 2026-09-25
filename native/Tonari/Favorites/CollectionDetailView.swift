import SwiftUI
import TonariCore

/// A group's works and videos; `collectionId == nil` shows every favorite.
struct CollectionDetailView: View {
    let collectionId: String?

    @Environment(\.appDatabase) private var database
    @State private var title = ""
    @State private var works: [Work] = []
    @State private var videos: [VideoItem] = []
    @State private var kind = AppModel.LibraryKind.audio

    var body: some View {
        ScrollView {
            if !works.isEmpty && !videos.isEmpty {
                Picker("类型", selection: $kind) {
                    ForEach(AppModel.LibraryKind.allCases, id: \.self) { Text($0.rawValue) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 12)
            }
            if showsVideos {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(videos) { VideoRow(video: $0) }
                }
                .padding(12)
            } else {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(works) { work in
                        NavigationLink(value: Route.work(work.productId)) {
                            WorkGridCell(work: work, isRemote: false)
                        }
                        .buttonStyle(.plain)
                        .workContextMenu(work, trackCount: nil, removeFromCollection: collectionId.map { id in
                            { try! database.setMembership(work: work.productId, collection: id, member: false) }
                        })
                    }
                }
                .padding(12)
            }
        }
        .background(Color(.systemGroupedBackground))
        .overlay {
            if works.isEmpty && videos.isEmpty {
                ContentUnavailableView(
                    collectionId == nil ? "还没有收藏" : "分组还是空的",
                    systemImage: collectionId == nil ? "heart" : "folder",
                    description: Text(collectionId == nil ? "点作品封面右上角或详情页的红心即可加入" : "在媒体库长按作品即可加入")
                )
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await database.observe({ [collectionId] db in
                if let collectionId {
                    (
                        try LibraryCollection.fetchOne(db, key: collectionId)?.name ?? "",
                        try CollectionQueries.works(in: collectionId, db),
                        try CollectionQueries.videos(in: collectionId, db)
                    )
                } else {
                    ("全部收藏", try CollectionQueries.favoriteWorks(db), try CollectionQueries.favoriteVideos(db))
                }
            }) {
                title = $0.0
                works = $0.1
                videos = $0.2
            }
        }
    }

    private var showsVideos: Bool {
        works.isEmpty ? !videos.isEmpty : (kind == .video && !videos.isEmpty)
    }
}
