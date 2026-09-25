import SwiftUI
import TonariCore

/// 按标签挑: every tag in the library, the ones listened to lately first.
/// Pick one to see its works, or several to let chance choose among the
/// works carrying all of them.
struct TagPickerSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.appDatabase) private var database
    @Environment(\.dismiss) private var dismiss
    @State private var tags: [HomeQueries.Tag] = []
    @State private var selected: [String] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text("常听的在前，其余按作品数").font(.footnote).foregroundStyle(.secondary)
                    FlowLayout(spacing: 8, lineSpacing: 8) {
                        ForEach(tags, id: \.name) { tag in chip(tag) }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .navigationTitle("按标签挑")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭", systemImage: "xmark") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) { actions }
        }
        .presentationDetents([.medium, .large])
        .task {
            tags = try! await database.reader.read { try HomeQueries.tags($0) }
        }
    }

    private func chip(_ tag: HomeQueries.Tag) -> some View {
        let on = selected.contains(tag.name)
        return Button {
            if on { selected.removeAll { $0 == tag.name } } else { selected.append(tag.name) }
        } label: {
            HStack(spacing: 4) {
                Text(tag.name)
                Text("\(tag.count)").foregroundStyle(on ? AnyShapeStyle(.white.opacity(0.75)) : AnyShapeStyle(.secondary))
            }
            .font(.subheadline)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .foregroundStyle(on ? .white : .primary)
            .background(on ? Color.accentColor : Color(.tertiarySystemFill), in: .capsule)
        }
        .buttonStyle(.plain)
    }

    private var actions: some View {
        HStack(spacing: 12) {
            Button {
                open(.chip(WorkChip(.genre, selected[0])))
            } label: {
                Text(selected.count == 1 ? "查看「\(selected[0])」" : "查看作品").frame(maxWidth: .infinity)
            }
            .disabled(selected.count != 1)
            Button {
                dismiss()
                model.openRandomWork(tagged: Set(selected), database: database)
            } label: {
                Label("随机一部", systemImage: "shuffle").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(selected.isEmpty)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private func open(_ route: Route) {
        dismiss()
        model.push(route)
    }
}
