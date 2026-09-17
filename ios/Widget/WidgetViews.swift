import Charts
import MinehutKit
import SwiftUI
import WidgetKit

private enum WidgetTheme {
    static let navy = Color(red: 0.035, green: 0.065, blue: 0.12)
    static let cyan = Color(red: 0.27, green: 0.84, blue: 0.98)
    static let mint = Color(red: 0.40, green: 0.95, blue: 0.73)
    static let palette: [Color] = [cyan, mint, .orange, .purple, .pink, .yellow]
    static func series(_ index: Int) -> Color { palette[index % palette.count] }
    static func delta(_ text: String) -> Color {
        text.hasPrefix("+") ? mint : text.hasPrefix("-") ? .orange : .secondary
    }
}

private func statusText(_ entry: WidgetEntry) -> String {
    guard let content = entry.content else { return entry.message ?? "No data yet" }
    if !content.ready { return "Collecting data" }
    return content.kind == .rising ? "No risers right now" : "No servers online"
}

private func listURL(_ entry: WidgetEntry) -> URL {
    (entry.kind == .top ? AppRoute.top : AppRoute.rising).url
}

struct MinehutWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var colorScheme
    let entry: WidgetEntry
    private var accessory: Bool { family == .accessoryInline || family == .accessoryRectangular }
    private var destination: URL {
        if family == .systemSmall, let row = entry.content?.rows.first {
            return AppRoute.server(id: row.id).url
        }
        return listURL(entry)
    }

    var body: some View {
        Group {
            switch family {
            case .accessoryInline:
                Text((entry.isOffline ? "Cached · " : "") + (entry.content?.inlineText ?? statusText(entry)))
            case .accessoryRectangular:
                RectangularView(entry: entry)
            case .systemSmall:
                SmallView(entry: entry)
            default:
                RankingsView(entry: entry, large: family == .systemLarge)
            }
        }
        .containerBackground(for: .widget) {
            if accessory { Color.clear }
            else {
                LinearGradient(colors: [WidgetTheme.navy, Color(red: 0.055, green: 0.14, blue: 0.21)], startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }
        .environment(\.colorScheme, accessory ? colorScheme : .dark)
        .widgetURL(destination)
    }
}

private struct HeaderView: View {
    let entry: WidgetEntry
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: entry.kind == .top ? "trophy.fill" : "chart.line.uptrend.xyaxis")
                .foregroundStyle(WidgetTheme.cyan)
            Text(entry.kind == .top ? "TOP SERVERS" : "RISING")
                .tracking(1.1)
                .foregroundStyle(.white.opacity(0.8))
            Spacer(minLength: 0)
            Text(entry.content?.periodLabel ?? "")
                .foregroundStyle(WidgetTheme.mint)
        }
        .font(.system(size: 10, weight: .bold))
        .widgetAccentable()
    }
}

private struct FreshnessView: View {
    let entry: WidgetEntry
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: entry.isOffline ? "wifi.slash" : "clock")
            if let updatedAt = entry.content?.updatedAt {
                Text(entry.isOffline ? "Cached" : "Updated")
                Text(unixDate(updatedAt), style: .relative).monospacedDigit()
            } else { Text("Awaiting update") }
            Spacer(minLength: 0)
        }
        .font(.system(size: 9, weight: .medium))
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }
}

private struct EmptyView: View {
    let entry: WidgetEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: entry.content == nil ? "antenna.radiowaves.left.and.right.slash" : "chart.xyaxis.line")
                .font(.title2).foregroundStyle(WidgetTheme.cyan)
            Text(statusText(entry)).font(.subheadline.weight(.semibold))
            if entry.content?.ready == false {
                Text("Rankings appear when a comparison is available.").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

private struct SmallView: View {
    let entry: WidgetEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HeaderView(entry: entry)
            if let row = entry.content?.rows.first {
                Spacer(minLength: 0)
                Text(row.name).font(.subheadline.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.75)
                Text(WidgetFormatters.count(row.players))
                    .font(.system(size: 38, weight: .bold))
                    .monospacedDigit().lineLimit(1).minimumScaleFactor(0.65)
                    .foregroundStyle(WidgetTheme.cyan)
                    .accessibilityLabel("\(row.players) players")
                HStack(spacing: 5) {
                    Text("players").foregroundStyle(.secondary)
                    if !row.shortDelta.isEmpty {
                        Text(row.shortDelta).foregroundStyle(WidgetTheme.delta(row.shortDelta)).fontWeight(.bold)
                    }
                }.font(.caption2)
                Spacer(minLength: 0)
            } else { EmptyView(entry: entry) }
            FreshnessView(entry: entry)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

private struct RankingsView: View {
    let entry: WidgetEntry
    let large: Bool
    private var rows: [WidgetRow] { Array((entry.content?.rows ?? []).prefix(large ? (entry.kind == .top ? 5 : 8) : 3)) }
    private var series: [WidgetSeries] {
        let ids = Set(rows.map(\.id))
        return (entry.content?.series ?? []).filter { ids.contains($0.id) }
    }
    private var showsChart: Bool { large && entry.kind == .top && series.contains { !$0.points.isEmpty } }

    var body: some View {
        VStack(alignment: .leading, spacing: large ? 9 : 6) {
            HeaderView(entry: entry)
            if rows.isEmpty { EmptyView(entry: entry) }
            else {
                ForEach(rows) { row in
                    Link(destination: AppRoute.server(id: row.id).url) {
                        RowView(row: row, rankColor: showsChart ? series.first(where: { $0.id == row.id }).map { WidgetTheme.series($0.colorIndex) } : nil)
                    }
                }
                if showsChart {
                    Divider().overlay(.white.opacity(0.08))
                    HStack {
                        Text("PLAYER HISTORY").tracking(0.8)
                        Spacer()
                        Text("24h")
                    }.font(.system(size: 9, weight: .semibold)).foregroundStyle(.secondary)
                    SeriesChart(series: series, updatedAt: entry.content?.updatedAt ?? Int(entry.date.timeIntervalSince1970))
                        .frame(maxHeight: .infinity)
                } else {
                    Spacer(minLength: 0)
                    if large && entry.kind == .top {
                        Text("Player history is collecting.").font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
            FreshnessView(entry: entry)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct SeriesChart: View {
    let series: [WidgetSeries]
    let updatedAt: Int
    var body: some View {
        Chart {
            ForEach(series) { line in
                ForEach(line.segments) { segment in
                  ForEach(segment.points) { point in
                    LineMark(x: .value("Time", point.date), y: .value("Players", point.players), series: .value("Server", "\(line.id.count):\(line.id):\(segment.id)"))
                        .foregroundStyle(WidgetTheme.series(line.colorIndex))
                        .lineStyle(StrokeStyle(lineWidth: 1.8, lineJoin: .round))
                    if segment.points.count == 1 {
                        PointMark(x: .value("Time", point.date), y: .value("Players", point.players))
                            .foregroundStyle(WidgetTheme.series(line.colorIndex)).symbolSize(12)
                    }
                  }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 2)) { _ in
                AxisValueLabel(format: .dateTime.hour().minute()).font(.system(size: 8))
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                AxisGridLine().foregroundStyle(.white.opacity(0.08))
                AxisValueLabel {
                    if let count = value.as(Int.self) { Text(WidgetFormatters.count(count)).font(.system(size: 8)) }
                }
            }
        }
        .chartYScale(domain: 0...max(series.flatMap(\.points).map(\.players).max() ?? 0, 1))
        .chartXScale(domain: unixDate(updatedAt - 86_400)...unixDate(updatedAt))
        .chartLegend(.hidden)
        .accessibilityLabel("Observed player history for the displayed top servers")
    }
}

private struct RowView: View {
    let row: WidgetRow
    let rankColor: Color?
    var body: some View {
        HStack(spacing: 7) {
            Text(String(format: "%02d", row.rank))
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(rankColor ?? WidgetTheme.cyan).frame(width: 18)
            Text(row.name).font(.system(size: 12, weight: .semibold)).lineLimit(1)
            Spacer(minLength: 2)
            Text(WidgetFormatters.count(row.players)).font(.system(size: 13, weight: .bold)).monospacedDigit()
            Text(row.shortDelta.isEmpty ? "·" : row.shortDelta)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(WidgetTheme.delta(row.shortDelta)).frame(minWidth: 32, alignment: .trailing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Rank \(row.rank), \(row.name), \(row.players) players. \(row.delta.isEmpty ? "Change unavailable" : row.delta)")
    }
}

private struct RectangularView: View {
    let entry: WidgetEntry
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Text(entry.kind == .top ? "TOP SERVERS" : "RISING")
                Spacer(minLength: 0)
                if entry.isOffline { Image(systemName: "wifi.slash") }
                Text(entry.content?.periodLabel ?? "")
            }.font(.system(size: 9, weight: .bold)).widgetAccentable()
            if let rows = entry.content?.rows, !rows.isEmpty {
                ForEach(Array(rows.prefix(2))) { row in
                    HStack(spacing: 4) {
                        Text("\(row.rank)").foregroundStyle(.secondary)
                        Text(row.name).lineLimit(1)
                        Spacer(minLength: 2)
                        Text(entry.kind == .top ? WidgetFormatters.count(row.players) : row.shortDelta).monospacedDigit().fontWeight(.semibold)
                    }.font(.caption)
                }
            } else { Text(statusText(entry)).font(.caption) }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
