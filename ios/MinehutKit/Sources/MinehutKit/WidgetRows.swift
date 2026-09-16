import Foundation

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

    public init(
        kind: WidgetListKind,
        updatedAt: Int,
        ready: Bool,
        rows: [WidgetRow],
        inlineText: String,
        series: [WidgetSeries] = []
    ) {
        self.kind = kind
        self.updatedAt = updatedAt
        self.ready = ready
        self.rows = rows
        self.inlineText = inlineText
        self.series = series
    }

    public static func rising(_ response: RisingResponse, limit: Int) -> WidgetContent {
        let rows = response.servers.prefix(limit).enumerated().map { index, server in
            WidgetRow(
                id: server.id,
                rank: index + 1,
                name: server.name,
                players: server.players,
                delta: Formatters.gain(server.gain, pct: server.pct),
                shortDelta: "+\(server.gain)"
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
        return WidgetContent(kind: .rising, updatedAt: response.updatedAt, ready: response.ready, rows: rows, inlineText: inline)
    }

    public static func top(_ response: TopResponse, limit: Int) -> WidgetContent {
        let rows = response.servers.prefix(limit).enumerated().map { index, server in
            topRow(index: index, id: server.id, name: server.name, players: server.players, change24h: server.change24h)
        }
        return WidgetContent(kind: .top, updatedAt: response.updatedAt, ready: true, rows: rows, inlineText: topInline(rows))
    }

    public static func topSeries(_ response: TopSeriesResponse, limit: Int) -> WidgetContent {
        let chosen = Array(response.servers.prefix(limit))
        let rows = chosen.enumerated().map { index, server in
            topRow(index: index, id: server.id, name: server.name, players: server.players, change24h: server.change24h)
        }
        let series = chosen.enumerated().map { index, server in
            WidgetSeries(id: server.id, colorIndex: index, points: server.points)
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

    private static func topRow(index: Int, id: String, name: String, players: Int, change24h: Int?) -> WidgetRow {
        let change = Formatters.change(change24h)
        return WidgetRow(id: id, rank: index + 1, name: name, players: players, delta: change, shortDelta: change)
    }

    private static func topInline(_ rows: [WidgetRow]) -> String {
        rows.first.map { "#1 \($0.name) \($0.players)" } ?? "No servers online"
    }
}
