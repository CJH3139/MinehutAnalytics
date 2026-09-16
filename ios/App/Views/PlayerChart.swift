import Charts
import MinehutKit
import SwiftUI

struct PlayerChart: View {
    let points: [GraphPoint]
    let range: GraphRange

    private struct Sample: Identifiable {
        let id: Int
        let segment: Int
        let date: Date
        let players: Int
    }

    private var samples: [Sample] {
        let maxStep = range == .day ? 1350 : 5400
        var segment = 0
        var result: [Sample] = []
        for (index, point) in points.enumerated() {
            if index > 0, point.ts - points[index - 1].ts > maxStep { segment += 1 }
            result.append(Sample(id: point.ts, segment: segment, date: point.date, players: point.players))
        }
        return result
    }

    var body: some View {
        if points.isEmpty {
            Text("No data for this range yet.")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 200)
        } else {
            Chart(samples) { sample in
                LineMark(
                    x: .value("Time", sample.date),
                    y: .value("Players", sample.players),
                    series: .value("Segment", sample.segment)
                )
                .foregroundStyle(Color.accentColor)
                .interpolationMethod(.monotone)
                if range == .day {
                    PointMark(x: .value("Time", sample.date), y: .value("Players", sample.players))
                        .foregroundStyle(Color.accentColor)
                        .symbolSize(10)
                }
            }
            .chartYScale(domain: .automatic(includesZero: true))
        }
    }
}
