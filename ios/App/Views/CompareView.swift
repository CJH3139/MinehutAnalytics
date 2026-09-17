import Charts
import MinehutKit
import SwiftUI

struct CompareView: View {
    @Environment(FavoritesModel.self) private var favorites
    @State private var top = LoadModel<TopResponse>()
    @State private var first = LoadModel<ServerDetailResponse>()
    @State private var second = LoadModel<ServerDetailResponse>()
    @State private var firstID = ""
    @State private var secondID = ""
    @State private var range: GraphRange = .day

    private struct Choice: Identifiable { let id: String; let name: String }
    private var choices: [Choice] {
        var result = favorites.collection.servers.map { Choice(id: $0.id, name: $0.name) }
        for server in top.value?.servers ?? [] where !result.contains(where: { $0.id == server.id }) {
            result.append(Choice(id: server.id, name: server.name))
        }
        return result.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    private var requestKey: String { "\(firstID)|\(secondID)|\(range.rawValue)" }
    private var ready: Bool { !firstID.isEmpty && !secondID.isEmpty && firstID != secondID }

    var body: some View {
        List {
            Section {
                Text("Side by side.").font(.title2.bold())
                Text("Select two saved or listed servers. Both histories use the same range and overlapping observation period.").font(.callout).foregroundStyle(.secondary)
                Picker("First server", selection: $firstID) {
                    Text("Choose a server").tag("")
                    ForEach(choices) { Text($0.name).tag($0.id) }
                }.tint(AnalyticsTheme.cyan)
                Picker("Second server", selection: $secondID) {
                    Text("Choose a server").tag("")
                    ForEach(choices) { Text($0.name).tag($0.id) }
                }.tint(AnalyticsTheme.mint)
                RangePicker(range: $range)
            }.listRowBackground(AnalyticsTheme.surface)
            if !firstID.isEmpty && firstID == secondID {
                Text("Choose two different servers to compare.").foregroundStyle(.secondary)
            } else if ready {
                if let a = first.value, let b = second.value,
                   a.server.id == firstID, b.server.id == secondID, a.range == range, b.range == range {
                    let shared = ComparisonObservations(first: a.points, second: b.points)
                    Section {
                        comparisonChart(shared, a: a.server.name, b: b.server.name, updatedAt: min(a.updatedAt, b.updatedAt))
                        Text("\(range.rawValue) · \(range == .day ? "observed samples" : "hourly peaks"). Missing observations are not filled in.").font(.caption).foregroundStyle(.secondary)
                    } header: { Text("Player history") }.listRowBackground(AnalyticsTheme.surface)
                    comparisonSection(a, points: shared.first, color: AnalyticsTheme.cyan, offline: first.isOffline)
                    comparisonSection(b, points: shared.second, color: AnalyticsTheme.mint, offline: second.isOffline)
                } else if let error = first.error ?? second.error {
                    ErrorStateView(error: error) { Task { await reload() } }
                } else { LoadingRow() }
            } else if top.isLoading { LoadingRow() }
            else if choices.isEmpty { ContentUnavailableView("No servers available", systemImage: "server.rack", description: Text("Save a server to your Watchlist or refresh the listings.")) }
        }.analyticsList().navigationTitle("Compare").navigationBarTitleDisplayMode(.inline)
            .task { await top.load(.top) }
            .task(id: requestKey) { await reload() }
            .refreshable { await top.load(.top); await reload() }
    }

    @ViewBuilder private func comparisonChart(_ shared: ComparisonObservations, a: String, b: String, updatedAt: Int) -> some View {
        if let start = shared.start, let end = shared.end, start < end, !shared.first.isEmpty, !shared.second.isEmpty {
            Chart {
                ForEach(segments(shared.first)) { sample in
                    LineMark(x: .value("Time", sample.point.date), y: .value("Players", sample.point.players), series: .value("Segment", "a\(sample.segment)"))
                        .foregroundStyle(AnalyticsTheme.cyan)
                    PointMark(x: .value("Time", sample.point.date), y: .value("Players", sample.point.players)).foregroundStyle(AnalyticsTheme.cyan).symbolSize(8)
                }
                ForEach(segments(shared.second)) { sample in
                    LineMark(x: .value("Time", sample.point.date), y: .value("Players", sample.point.players), series: .value("Segment", "b\(sample.segment)"))
                        .foregroundStyle(AnalyticsTheme.mint).lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 3]))
                    PointMark(x: .value("Time", sample.point.date), y: .value("Players", sample.point.players)).foregroundStyle(AnalyticsTheme.mint).symbolSize(8)
                }
            }.chartXScale(domain: unixDate(updatedAt - (range == .day ? 86400 : (range == .week ? 604800 : 2592000)))...unixDate(updatedAt)).chartYScale(domain: .automatic(includesZero: true)).frame(height: 230)
                .accessibilityLabel("Player observations for \(a) and \(b)")
            VStack(alignment: .leading, spacing: 6) {
                Label(a + " · solid line", systemImage: "circle.fill").foregroundStyle(AnalyticsTheme.cyan)
                Label(b + " · dashed line", systemImage: "diamond.fill").foregroundStyle(AnalyticsTheme.mint)
            }.font(.caption)
        } else {
            ContentUnavailableView("Not enough shared history", systemImage: "chart.xyaxis.line", description: Text("These servers need observations in an overlapping time period."))
        }
    }

    private struct Sample: Identifiable {
        let point: GraphPoint
        let segment: Int
        var id: Int { point.ts }
    }
    private func segments(_ points: [GraphPoint]) -> [Sample] {
        var segment = 0
        return points.enumerated().map { index, point in
            if index > 0 && point.ts - points[index - 1].ts > (range == .day ? 1350 : 5400) { segment += 1 }
            return Sample(point: point, segment: segment)
        }
    }
    private func comparisonSection(_ response: ServerDetailResponse, points: [GraphPoint], color: Color, offline: Bool) -> some View {
        let stats = ObservationStatistics(points: points)
        return Section {
            HStack { ServerAvatar(icon: response.server.icon); Text(response.server.name).font(.headline).foregroundStyle(color) }
            LabeledContent("Latest players", value: response.server.players.formatted())
            LabeledContent("Shared-period peak", value: stats.peak.map { $0.formatted() } ?? "Unavailable")
            LabeledContent(range == .day ? "Shared-period observed mean" : "Shared-period mean hourly peak", value: stats.mean.map { $0.formatted(.number.precision(.fractionLength(1))) } ?? "Unavailable")
            UpdatedHeader(updatedAt: response.updatedAt, isOffline: offline)
        }.listRowBackground(AnalyticsTheme.surface)
    }
    private func reload() async {
        guard ready else { return }
        async let a: () = first.load(.server(id: firstID, range: range))
        async let b: () = second.load(.server(id: secondID, range: range))
        _ = await (a, b)
    }
}
