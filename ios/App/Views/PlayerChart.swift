import Charts
import MinehutKit
import SwiftUI

struct PlayerChart: View {
    let points: [GraphPoint]
    let range: GraphRange
    var gapTolerance: Int? = nil
    var updatedAt: Int? = nil

    private struct Sample: Identifiable {
        let id: Int
        let segment: Int
        let date: Date
        let players: Int
    }
    private var samples: [Sample] {
        let sorted = points.sorted { $0.ts < $1.ts }
        let maxStep = gapTolerance ?? (range == .day ? 1350 : 5400)
        var segment = 0
        return sorted.enumerated().map { index, point in
            if index > 0, point.ts - sorted[index - 1].ts > maxStep { segment += 1 }
            return Sample(id: point.ts, segment: segment, date: point.date, players: point.players)
        }
    }
    private var domain: ClosedRange<Date> {
        let end = updatedAt ?? points.map(\.ts).max() ?? Int(Date.now.timeIntervalSince1970)
        let seconds = range == .day ? 86400 : (range == .week ? 604800 : 2592000)
        return unixDate(end - seconds)...unixDate(end)
    }
    var body: some View {
        if points.isEmpty {
            ContentUnavailableView("No observations yet", systemImage: "chart.xyaxis.line", description: Text("History will appear as samples arrive."))
        } else {
            Chart(samples) { sample in
                LineMark(x: .value("Time", sample.date), y: .value("Players", sample.players), series: .value("Segment", sample.segment))
                    .foregroundStyle(AnalyticsTheme.cyan).lineStyle(StrokeStyle(lineWidth: 2))
                PointMark(x: .value("Time", sample.date), y: .value("Players", sample.players))
                    .foregroundStyle(AnalyticsTheme.cyan).symbolSize(8)
            }
            .chartXScale(domain: domain)
            .chartYScale(domain: .automatic(includesZero: true))
            .accessibilityLabel("Player history over \(range.rawValue), \(points.count) observations")
        }
    }
}

#Preview("Observed history") {
    let end = 1_789_000_200
    return PlayerChart(
        points: [GraphPoint(ts: end - 3600, players: 42), GraphPoint(ts: end - 2700, players: 55), GraphPoint(ts: end - 900, players: 48), GraphPoint(ts: end, players: 62)],
        range: .day,
        updatedAt: end
    ).frame(height: 240).padding().background(AnalyticsTheme.background).preferredColorScheme(.dark)
}
