import Foundation

public enum WidgetFormatters {
    public static func count(_ value: Int) -> String {
        let magnitude = abs(Double(value))
        let divisor: Double
        let suffix: String
        if magnitude >= 999_950 { divisor = 1_000_000; suffix = "M" }
        else if magnitude >= 1_000 { divisor = 1_000; suffix = "K" }
        else { return String(value) }
        let rounded = (Double(value) / divisor * 10).rounded() / 10
        return String(format: rounded.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f%@" : "%.1f%@", locale: Locale(identifier: "en_US_POSIX"), rounded, suffix)
    }

    public static func change(_ value: Int) -> String {
        (value > 0 ? "+" : "") + count(value)
    }
}

public enum WidgetListKind: String, Sendable {
    case rising
    case top
}

public struct WidgetRow: Equatable, Sendable, Identifiable {
    public let id: String
    public let rank: Int
    public let name: String
    public let players: Int
    public let delta: String
    public let shortDelta: String

    public init(id: String, rank: Int, name: String, players: Int, delta: String, shortDelta: String) {
        self.id = id
        self.rank = rank
        self.name = name
        self.players = players
        self.delta = delta
        self.shortDelta = shortDelta
    }
}

public struct WidgetSeries: Equatable, Sendable, Identifiable {
    public let id: String
    public let colorIndex: Int
    public let points: [GraphPoint]

    public struct Segment: Identifiable, Sendable {
        public let id: Int
        public let points: [GraphPoint]
    }

    /// The existing top-series endpoint samples every 15 minutes. Break lines
    /// across missing snapshots instead of implying continuous observations.
    public var segments: [Segment] {
        var groups: [[GraphPoint]] = []
        for point in points {
            if let last = groups.last?.last, point.ts - last.ts <= 900 {
                groups[groups.count - 1].append(point)
            } else {
                groups.append([point])
            }
        }
        return groups.enumerated().map { Segment(id: $0.offset, points: $0.element) }
    }

    public init(id: String, colorIndex: Int, points: [GraphPoint]) {
        self.id = id
        self.colorIndex = colorIndex
        self.points = points
    }
}

public struct WidgetContent: Equatable, Sendable {
    public let kind: WidgetListKind
    public let updatedAt: Int
    public let ready: Bool
    public let rows: [WidgetRow]
    public let inlineText: String
    public let series: [WidgetSeries]
    public let periodLabel: String

    public init(
        kind: WidgetListKind,
        updatedAt: Int,
        ready: Bool,
        rows: [WidgetRow],
        inlineText: String,
        series: [WidgetSeries] = [],
        periodLabel: String = "24h"
    ) {
        self.kind = kind
        self.updatedAt = updatedAt
        self.ready = ready
        self.rows = rows
        self.inlineText = inlineText
        self.series = series
        self.periodLabel = periodLabel
    }

    public static func rising(_ response: RisingResponse, limit: Int) -> WidgetContent {
        let rows = unique(response.servers).prefix(max(0, limit)).enumerated().map { index, server in
            WidgetRow(
                id: server.id,
                rank: index + 1,
                name: server.name,
                players: server.players,
                delta: Formatters.gain(server.gain, pct: server.pct),
                shortDelta: WidgetFormatters.change(server.gain)
            )
        }
        let inline: String
        if !response.ready {
            inline = "Collecting data"
        } else if let first = rows.first {
            inline = "↑ \(first.name) \(first.shortDelta)"
        } else {
            inline = "No risers right now"
        }
        return WidgetContent(kind: .rising, updatedAt: response.updatedAt, ready: response.ready, rows: rows, inlineText: inline, periodLabel: response.window.rawValue)
    }

    public static func top(_ response: TopResponse, limit: Int) -> WidgetContent {
        let rows = unique(response.servers).prefix(max(0, limit)).enumerated().map { index, server in
            topRow(index: index, id: server.id, name: server.name, players: server.players, change24h: server.change24h)
        }
        return WidgetContent(kind: .top, updatedAt: response.updatedAt, ready: true, rows: rows, inlineText: topInline(rows))
    }

    public static func topSeries(_ response: TopSeriesResponse, limit: Int) -> WidgetContent {
        let chosen = Array(unique(response.servers).prefix(max(0, limit)))
        let rows = chosen.enumerated().map { index, server in
            topRow(index: index, id: server.id, name: server.name, players: server.players, change24h: server.change24h)
        }
        let series = chosen.enumerated().map { index, server in
            WidgetSeries(id: server.id, colorIndex: index, points: normalizedPoints(server.points))
        }
        return WidgetContent(
            kind: .top,
            updatedAt: response.updatedAt,
            ready: true,
            rows: rows,
            inlineText: topInline(rows),
            series: series
        )
    }

    private static func unique<T: Identifiable>(_ values: [T]) -> [T] where T.ID: Hashable {
        var seen = Set<T.ID>()
        return values.filter { seen.insert($0.id).inserted }
    }

    private static func normalizedPoints(_ points: [GraphPoint]) -> [GraphPoint] {
        var byTime: [Int: GraphPoint] = [:]
        for point in points { byTime[point.ts] = point }
        return byTime.values.sorted { $0.ts < $1.ts }
    }

    private static func topRow(index: Int, id: String, name: String, players: Int, change24h: Int?) -> WidgetRow {
        let change = Formatters.change(change24h)
        return WidgetRow(id: id, rank: index + 1, name: name, players: players, delta: change, shortDelta: change24h.map(WidgetFormatters.change) ?? "")
    }

    private static func topInline(_ rows: [WidgetRow]) -> String {
        rows.first.map { "#1 \($0.name) \(WidgetFormatters.count($0.players))" } ?? "No servers online"
    }
}
