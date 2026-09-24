import Charts
import SwiftUI
import TonariCore

/// Listening time from the logs the player writes every few seconds.
struct ListenStatsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.appDatabase) private var database
    @State private var stats: ListenStats?
    @State private var selectedDay: Date?

    var body: some View {
        List {
            if let stats, !stats.isEmpty {
                Section {
                    HStack {
                        total("累计", stats.totalMs)
                        total("本周", stats.weekMs)
                        total("本月", stats.monthMs)
                    }
                }
                Section {
                    daily(stats)
                } header: {
                    Text("最近 \(ListenStats.dailyWindow) 天")
                }
                if !stats.topWorks.isEmpty {
                    Section("排行榜") {
                        Rankings(stats: stats)
                    }
                }
            }
        }
        .overlay {
            if let stats, stats.isEmpty {
                ContentUnavailableView("还没有收听记录", systemImage: "chart.bar", description: Text("播放音声后，收听时长会记录在这里"))
            }
        }
        .navigationTitle("收听统计")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await database.observe({ db in try ListenStats.fetch(db) }) { stats = $0 }
        }
    }

    private func total(_ label: String, _ ms: Int) -> some View {
        VStack(spacing: 2) {
            Text(Formatting.listening(ms: ms)).font(.headline).foregroundStyle(.tint).multilineTextAlignment(.center)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func daily(_ stats: ListenStats) -> some View {
        let calendar = Calendar.current
        let selected = selectedDay.flatMap { day in stats.daily.first { calendar.isDate($0.date, inSameDayAs: day) } }
        return VStack(alignment: .leading, spacing: 8) {
            Text(selected.map { "\($0.date.formatted(.dateTime.month().day())) · \(Formatting.listening(ms: $0.ms))" } ?? "点按柱子查看当天")
                .font(.caption)
                .foregroundStyle(.secondary)
            Chart(stats.daily) { day in
                BarMark(x: .value("日期", day.date, unit: .day), y: .value("分钟", Double(day.ms) / 60_000))
                    .foregroundStyle(selected?.date == day.date ? Color.accentColor : Color.accentColor.opacity(selected == nil ? 1 : 0.4))
                    .cornerRadius(2)
            }
            .chartXSelection(value: $selectedDay)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                    AxisValueLabel(format: .dateTime.month(.defaultDigits).day())
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel { Text("\(value.as(Double.self).map { Int($0) } ?? 0) 分") }
                }
            }
            .frame(height: 160)
        }
        .padding(.vertical, 4)
    }
}

/// Top five works, voice actors and circles, one page each: switch with the
/// segmented control or by swiping, at a fixed height.
private struct Rankings: View {
    enum Board: String, CaseIterable {
        case works = "作品"
        case voiceActors = "声优"
        case circles = "社团"
    }

    let stats: ListenStats

    @Environment(AppModel.self) private var model
    @State private var board = Board.works

    private static let rowHeight: CGFloat = 56

    var body: some View {
        VStack(spacing: 10) {
            Picker("排行榜", selection: $board) {
                ForEach(Board.allCases, id: \.self) { Text($0.rawValue) }
            }
            .pickerStyle(.segmented)
            TabView(selection: $board) {
                page(stats.topWorks.map { ($0.item.productId, $0.item.displayTitle, $0.item.mainImageLocalPath, $0.ms) }) { id in
                    model.favoritesPath.append(Route.work(id))
                }
                .tag(Board.works)
                page(stats.topVoiceActors.map { ($0.item, $0.item, nil, $0.ms) }) { name in
                    model.showInLibrary(WorkChip(.voiceActor, name))
                }
                .tag(Board.voiceActors)
                page(stats.topCircles.map { ($0.item, $0.item, nil, $0.ms) }) { name in
                    model.showInLibrary(WorkChip(.circle, name))
                }
                .tag(Board.circles)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: Self.rowHeight * CGFloat(ListenStats.topCount))
        }
        .padding(.vertical, 6)
    }

    /// Rows of (id, title, cover, ms); a nil cover draws no artwork.
    private func page(_ rows: [(String, String, String?, Int)], open: @escaping (String) -> Void) -> some View {
        let top = rows.first?.3 ?? 1
        return VStack(spacing: 0) {
            if rows.isEmpty {
                Text("暂无记录").foregroundStyle(.secondary).frame(maxHeight: .infinity)
            }
            ForEach(Array(rows.enumerated()), id: \.element.0) { index, row in
                Button { open(row.0) } label: {
                    HStack(spacing: 12) {
                        Text("\(index + 1)")
                            .font(.title3.bold().monospacedDigit())
                            .foregroundStyle(index < 3 ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                            .frame(width: 22)
                        if let cover = row.2 {
                            LocalImage(path: cover).frame(width: 40, height: 40).clipShape(.rect(cornerRadius: 4))
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(row.1).font(.subheadline).lineLimit(1)
                                Spacer(minLength: 8)
                                Text(Formatting.listening(ms: row.3)).font(.caption).foregroundStyle(.secondary)
                            }
                            GeometryReader { proxy in
                                Capsule().fill(.tint.opacity(0.7))
                                    .frame(width: max(4, proxy.size.width * CGFloat(row.3) / CGFloat(top)))
                            }
                            .frame(height: 4)
                        }
                    }
                    .frame(height: Self.rowHeight)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
    }
}
