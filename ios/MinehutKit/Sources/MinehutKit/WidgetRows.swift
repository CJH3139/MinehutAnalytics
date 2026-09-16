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

public struct WidgetContent: Equatable, Sendable {
    public let kind: WidgetListKind
    public let updatedAt: Int
    public let ready: Bool
    public let rows: [WidgetRow]
    public let inlineText: String

    public init(kind: WidgetListKind, updatedAt: Int, ready: Bool, rows: [WidgetRow], inlineText: String) {
        self.kind = kind
        self.updatedAt = updatedAt
        self.ready = ready
        self.rows = rows
        self.inlineText = inlineText
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
        let rows = response.servers.prefix(limit).enumerated().map { index, server -> WidgetRow in
            let change = Formatters.change(server.change24h)
            return WidgetRow(
                id: server.id,
                rank: index + 1,
                name: server.name,
                players: server.players,
                delta: change,
                shortDelta: change
            )
        }
        let inline = rows.first.map { "#1 \($0.name) \($0.players)" } ?? "No servers online"
        return WidgetContent(kind: .top, updatedAt: response.updatedAt, ready: true, rows: rows, inlineText: inline)
    }
}
