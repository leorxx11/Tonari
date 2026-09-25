import SwiftUI
import TonariCore

/// A group's works and videos after an Apple Music playlist: collage, name
/// and count, then the works as rows. `collectionId == nil` shows
/// every favorite.
struct CollectionDetailView: View {
    let collectionId: String?

    @Environment(AppModel.self) private var model
    @Environment(VideoController.self) private var video
    @Environment(\.appDatabase) private var database
    @State private var title = ""
    @State private var works: [Work] = []
    @State private var videos: [VideoItem] = []
    @State private var trackCounts: [String: Int] = [:]
    @State private var remoteIds: Set<String> = []
    @State private var kind = Kind.audio
    @AppStorage(CollectionWorkSort.preferenceKey) private var sort = CollectionWorkSort.addedAt

    private enum Kind: String, CaseIterable {
        case audio = "作品"
        case video = "视频"
    }

    var body: some View {
        List {
            VStack(spacing: 20) {
                header
                if !works.isEmpty && !videos.isEmpty {
                    Picker("类型", selection: $kind) {
                        ForEach(Kind.allCases, id: \.self) { Text($0.rawValue) }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .padding(.bottom, 8)
            .listRowSeparator(.hidden)
            if showsVideos {
                ForEach(videos) { item in
                    Button { model.playVideo(PlayableVideo(item), with: video) } label: { VideoRow(video: item) }
                        .tint(.primary)
                        .swipeActions(edge: .trailing) {
                            if let collectionId {
                                Button("移出分组", systemImage: "folder.badge.minus", role: .destructive) {
                                    try! database.setMembership(video: item.id, collection: collectionId, member: false)
                                }
                            } else {
                                Button("取消收藏", systemImage: "heart.slash", role: .destructive) {
                                    try! database.setVideoFavorite(item.id, false)
                                }
                            }
                        }
                }
            } else {
                ForEach(works) { work in
                    NavigationLink(value: Route.work(work.productId)) {
                        WorkListRow(work: work, isRemote: work.importedFolderId.map(remoteIds.contains) ?? false, trackCount: trackCounts[work.productId] ?? 0)
                    }
                    .navigationLinkIndicatorVisibility(.hidden)
                    .workContextMenu(work, trackCount: trackCounts[work.productId] ?? 0, removeFromCollection: removal(work))
                    .swipeActions(edge: .trailing) {
                        if let removal = removal(work) {
                            Button("移出分组", systemImage: "folder.badge.minus", role: .destructive, action: removal)
                        } else {
                            Button("取消收藏", systemImage: "heart.slash", role: .destructive) {
                                try! database.setFavorite(work.productId, false)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .overlay {
            if works.isEmpty && videos.isEmpty {
                ContentUnavailableView(
                    collectionId == nil ? "还没有收藏" : "分组还是空的",
                    systemImage: collectionId == nil ? "heart" : "rectangle.stack",
                    description: Text(collectionId == nil ? "点作品详情页播放按钮旁的红心即可加入" : "在媒体库长按作品即可加入")
                )
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: sort) {
            await database.observe({ [collectionId, sort] db in
                (
                    try collectionId.flatMap { try LibraryCollection.fetchOne(db, key: $0)?.name } ?? "全部收藏",
                    try collectionId.map { try CollectionQueries.works(in: $0, sort: sort, db) } ?? CollectionQueries.favoriteWorks(sort: sort, db),
                    try collectionId.map { try CollectionQueries.videos(in: $0, db) } ?? CollectionQueries.favoriteVideos(db),
                    try WorkQueries.trackCounts(db),
                    try WorkQueries.remoteFolderIds(db)
                )
            }) {
                title = $0.0
                works = $0.1
                videos = $0.2
                trackCounts = $0.3
                remoteIds = $0.4
            }
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            CollageCover(covers: Array(works.compactMap(\.mainImageLocalPath).prefix(4)), cornerRadius: 12)
                .frame(width: 240)
                .shadow(color: .black.opacity(0.15), radius: 12, y: 6)
            VStack(spacing: 4) {
                Text(title).font(.title2.bold()).multilineTextAlignment(.center)
                Text(countText).font(.subheadline).foregroundStyle(.secondary)
            }
            if !works.isEmpty {
                HStack(spacing: 12) {
                    Button {
                        model.push(.work(works.randomElement()!.productId))
                    } label: {
                        Label("随机一部", systemImage: "dice").frame(maxWidth: .infinity)
                    }
                    Menu {
                        Picker("排序", selection: $sort) {
                            ForEach(CollectionWorkSort.allCases, id: \.self) { Text($0.label) }
                        }
                    } label: {
                        Label("排序", systemImage: "arrow.up.arrow.down").frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
                .padding(.top, 4)
            }
        }
        .padding(.top, 8)
    }

    private func removal(_ work: Work) -> (() -> Void)? {
        collectionId.map { id in { try! database.setMembership(work: work.productId, collection: id, member: false) } }
    }

    private var countText: String {
        [works.isEmpty ? nil : "\(works.count) 部作品", videos.isEmpty ? nil : "\(videos.count) 个视频"]
            .compactMap(\.self).joined(separator: " · ")
    }

    private var showsVideos: Bool {
        works.isEmpty ? !videos.isEmpty : (kind == .video && !videos.isEmpty)
    }
}
