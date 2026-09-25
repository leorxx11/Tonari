import SwiftUI
import TonariCore

/// Two lists: the DLsite account's wishlist (what to buy) and the local
/// 待入库 (what to add to the library, marked once it's in).
struct WishlistView: View {
    private enum Tab: Hashable {
        case dlsite, wanted
    }

    private enum Order: String, CaseIterable {
        case added = "加入时间"
        case discount = "折扣"
        case price = "价格"
    }

    @Environment(AppModel.self) private var model
    @Environment(\.appDatabase) private var database
    @State private var tab = Tab.dlsite
    @State private var order = Order.added
    @State private var wanted: [WantedWorks.Entry] = []

    var body: some View {
        List {
            Picker("清单", selection: $tab) {
                Text("DLsite 愿望单" + (model.wishlist.ids.map { " · \($0.count)" } ?? "")).tag(Tab.dlsite)
                Text("待入库 · \(wanted.count)").tag(Tab.wanted)
            }
            .pickerStyle(.segmented)
            .listRowSeparator(.hidden)
            switch tab {
            case .dlsite: dlsite
            case .wanted: wantedList
            }
        }
        .listStyle(.plain)
        .overlay { emptyState }
        .navigationTitle("愿望单")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if tab == .dlsite {
                Menu("排序", systemImage: "arrow.up.arrow.down") {
                    Picker("排序", selection: $order) {
                        ForEach(Order.allCases, id: \.self) { Text($0.rawValue) }
                    }
                }
            } else if wanted.contains(where: \.imported) {
                Button("清除已入库") { try! database.clearImportedWanted() }
            }
        }
        .refreshable { await model.wishlist.load(details: true) }
        .task { await model.wishlist.load(details: true) }
        .task { await database.observe(WantedWorks.all) { wanted = $0 } }
    }

    @ViewBuilder private var dlsite: some View {
        if model.wishlist.isSignedIn {
            ForEach(sorted) { item in
                NavigationLink(value: Route.onlineWork(item.productId)) {
                    CatalogRow(item: item, rank: nil, owned: false)
                }
                .navigationLinkIndicatorVisibility(.hidden)
                .swipeActions {
                    Button("移出", systemImage: "heart.slash", role: .destructive) {
                        Task { await model.wishlist.toggle(item.productId) }
                    }
                }
            }
            if model.wishlist.loading && model.wishlist.items.isEmpty {
                ProgressView().frame(maxWidth: .infinity).listRowSeparator(.hidden)
            }
        }
    }

    /// DLsite lists newest first; the other orders put the best deal or the
    /// cheapest on top.
    private var sorted: [CatalogItem] {
        let items = model.wishlist.items
        return switch order {
        case .added: items
        case .discount: items.sorted { ($0.discountRate ?? 0) > ($1.discountRate ?? 0) }
        case .price: items.sorted { ($0.price ?? .max) < ($1.price ?? .max) }
        }
    }

    private var wantedList: some View {
        ForEach(wanted) { entry in
            NavigationLink(value: entry.imported ? Route.work(entry.id) : Route.onlineWork(entry.id)) {
                HStack(spacing: 12) {
                    RemoteCover(url: URL(string: entry.work.coverUrl)!).frame(width: 96)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(entry.work.title).font(.subheadline.weight(.medium)).lineLimit(2)
                        Text(([entry.work.circle].compactMap(\.self) + [entry.work.addedAt.formatted(.relative(presentation: .named)) + "加入"]).joined(separator: " · "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Text(entry.imported ? "已入库 · 打开" : "待入库")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(entry.imported ? .green : .secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(entry.imported ? Color.green.opacity(0.14) : Color(.tertiarySystemFill), in: .rect(cornerRadius: 5))
                    }
                }
                .padding(.vertical, 2)
            }
            .navigationLinkIndicatorVisibility(.hidden)
            .swipeActions {
                Button("移除", systemImage: "trash", role: .destructive) { try! database.removeWanted(entry.id) }
            }
        }
    }

    @ViewBuilder private var emptyState: some View {
        switch tab {
        case .dlsite:
            if !model.wishlist.isSignedIn {
                ContentUnavailableView {
                    Label("还没有登录 DLsite", systemImage: "person.crop.circle.badge.questionmark")
                } description: {
                    Text("登录后在这里查看和整理你账号里的愿望单")
                } actions: {
                    Button("登录 DLsite") { model.showingDLsiteLogin = true }.buttonStyle(.borderedProminent)
                }
            } else if !model.wishlist.loading, model.wishlist.ids?.isEmpty == true {
                ContentUnavailableView("愿望单是空的", systemImage: "heart", description: Text("在作品页点「加入愿望单」"))
            }
        case .wanted:
            if wanted.isEmpty {
                ContentUnavailableView("没有待入库的作品", systemImage: "tray", description: Text("在作品页点收件箱图标，记下之后要放进资料库的作品"))
            }
        }
    }
}

/// Settings → DLsite: whether the account is signed in, and the way in or out.
struct DLsiteAccountView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        List {
            Section {
                LabeledContent("状态", value: model.wishlist.isSignedIn ? "已登录" : "未登录")
            }
            Section {
                if model.wishlist.isSignedIn {
                    Button("退出登录", role: .destructive) { model.wishlist.signOut() }
                } else {
                    Button("登录 DLsite") { model.showingDLsiteLogin = true }
                }
            }
        }
        .navigationTitle("DLsite")
        .navigationBarTitleDisplayMode(.inline)
    }
}
