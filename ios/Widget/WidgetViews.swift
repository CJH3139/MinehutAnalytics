import Charts
import MinehutKit
import SwiftUI
import WidgetKit

private func statusText(_ entry: WidgetEntry) -> String {
    guard let content = entry.content else { return entry.message ?? "No data yet" }
    if !content.ready { return "Collecting data" }
    return content.kind == .rising ? "No risers right now" : "No servers online"
}

private func listURL(_ entry: WidgetEntry) -> URL {
    (entry.kind == .top ? AppRoute.top : AppRoute.rising).url
}

private let seriesPalette: [Color] = [.teal, .orange, .purple, .pink, .blue, .green, .indigo, .red]

private func seriesColor(_ index: Int) -> Color {
    seriesPalette[((index % seriesPalette.count) + seriesPalette.count) % seriesPalette.count]
}

private func deltaColor(_ text: String) -> Color {
    if text.hasPrefix("+") { return .green }
    if text.hasPrefix("-") { return .red }
    return .secondary
}

struct MinehutWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WidgetEntry

    var body: some View {
        switch family {
        case .accessoryInline:
            Text(entry.content?.inlineText ?? statusText(entry))
        case .accessoryRectangular:
            RectangularView(entry: entry)
        case .systemSmall:
            SmallView(entry: entry)
        default:
            ListView(entry: entry, large: family == .systemLarge)
        }
    }
}

private struct HeaderView: View {
    let entry: WidgetEntry

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: entry.kind == .top ? "trophy.fill" : "chart.line.uptrend.xyaxis")
            Text(entry.kind == .top ? "Top" : "Rising").fontWeight(.semibold)
            if entry.isOffline { Image(systemName: "wifi.slash") }
            Spacer(minLength: 4)
            if let updatedAt = entry.content?.updatedAt {
                Text(unixDate(updatedAt), style: .relative)
                    .monospacedDigit()
                    .multilineTextAlignment(.trailing)
            }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .widgetAccentable()
    }
}

private struct SmallView: View {
    let entry: WidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HeaderView(entry: entry)
            Spacer(minLength: 0)
            if let row = entry.content?.rows.first {
                Text(row.name).font(.headline).lineLimit(1).minimumScaleFactor(0.7)
                Text("\(row.players)")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                HStack(spacing: 4) {
                    Text("players").foregroundStyle(.secondary)
                    if !row.shortDelta.isEmpty {
                        Text(row.shortDelta).fontWeight(.semibold).foregroundStyle(deltaColor(row.shortDelta))
                    }
                }
                .font(.caption)
            } else {
                Text(statusText(entry)).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .widgetURL(listURL(entry))
    }
}

private struct ListView: View {
    let entry: WidgetEntry
    let large: Bool

    private var series: [WidgetSeries] { entry.content?.series ?? [] }
    private var showsChart: Bool { large && entry.kind == .top && !series.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: large ? 6 : 4) {
            HeaderView(entry: entry)
            if let rows = entry.content?.rows, !rows.isEmpty {
                ForEach(rows) { row in
                    Link(destination: AppRoute.server(id: row.id).url) {
                        RowView(row: row, fullDelta: large, dotColor: showsChart ? seriesColor(row.rank - 1) : nil)
                    }
                }
                if showsChart {
                    SeriesChart(series: series)
                        .frame(maxHeight: .infinity)
                        .padding(.top, 2)
                }
            } else {
                Text(statusText(entry)).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .widgetURL(listURL(entry))
    }
}

private struct SeriesChart: View {
    let series: [WidgetSeries]

    private var upperBound: Int {
        Swift.max(series.flatMap(\.points).map(\.players).max() ?? 0, 1)
    }

    var body: some View {
        Chart {
            ForEach(series) { line in
                ForEach(line.points) { point in
                    LineMark(
                        x: .value("Time", point.date),
                        y: .value("Players", point.players),
                        series: .value("Server", line.id)
                    )
                    .foregroundStyle(seriesColor(line.colorIndex))
                    .lineStyle(StrokeStyle(lineWidth: 1.2, lineJoin: .round))
                }
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartYScale(domain: 0...upperBound)
        .chartLegend(.hidden)
    }
}

private struct RowView: View {
    let row: WidgetRow
    let fullDelta: Bool
    var dotColor: Color?

    var body: some View {
        HStack(spacing: 6) {
            Text("\(row.rank)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 16, alignment: .trailing)
            if let dotColor {
                Circle().fill(dotColor).frame(width: 6, height: 6)
            }
            Text(row.name).font(.subheadline.weight(.medium)).lineLimit(1)
            Spacer(minLength: 4)
            Text("\(row.players)").font(.subheadline.monospacedDigit())
            if !row.shortDelta.isEmpty {
                Text(fullDelta ? row.delta : row.shortDelta)
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(deltaColor(row.shortDelta))
            }
        }
    }
}

private struct RectangularView: View {
    let entry: WidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(entry.kind == .top ? "Top servers" : "Rising")
                .font(.caption2.weight(.semibold))
                .widgetAccentable()
            if let rows = entry.content?.rows, !rows.isEmpty {
                ForEach(rows) { row in
                    HStack(spacing: 4) {
                        Text(row.name).lineLimit(1)
                        Spacer(minLength: 2)
                        Text(entry.kind == .top ? "\(row.players)" : row.shortDelta).monospacedDigit()
                    }
                    .font(.caption)
                }
            } else {
                Text(statusText(entry)).font(.caption)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetURL(listURL(entry))
    }
}
