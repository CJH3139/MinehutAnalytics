import Foundation

public func unixDate(_ ts: Int) -> Date {
    Date(timeIntervalSince1970: TimeInterval(ts))
}

public enum RisingWindow: String, CaseIterable, Codable, Sendable, Identifiable {
    case oneHour = "1h"
    case sixHours = "6h"
    case day = "24h"

    public var id: String { rawValue }
}

public enum GraphRange: String, CaseIterable, Codable, Sendable, Identifiable {
    case day = "24h"
    case week = "7d"
    case month = "30d"

    public var id: String { rawValue }
}

public struct TopServer: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let players: Int
    public let maxPlayers: Int?
    public let change24h: Int?

    public init(id: String, name: String, players: Int, maxPlayers: Int?, change24h: Int?) {
        self.id = id
        self.name = name
        self.players = players
        self.maxPlayers = maxPlayers
        self.change24h = change24h
    }
}

public struct TopResponse: Codable, Equatable, Sendable {
    public let updatedAt: Int
    public let servers: [TopServer]

    public init(updatedAt: Int, servers: [TopServer]) {
        self.updatedAt = updatedAt
        self.servers = servers
    }
}

public struct RisingServer: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let players: Int
    public let then: Int
    public let gain: Int
    public let pct: Double?

    public init(id: String, name: String, players: Int, then: Int, gain: Int, pct: Double?) {
        self.id = id
        self.name = name
        self.players = players
        self.then = then
        self.gain = gain
        self.pct = pct
    }
}

public struct RisingResponse: Codable, Equatable, Sendable {
    public let updatedAt: Int
    public let window: RisingWindow
    public let ready: Bool
    public let readyAt: Int?
    public let comparedTo: Int?
    public let servers: [RisingServer]

    public init(updatedAt: Int, window: RisingWindow, ready: Bool, readyAt: Int?, comparedTo: Int?, servers: [RisingServer]) {
        self.updatedAt = updatedAt
        self.window = window
        self.ready = ready
        self.readyAt = readyAt
        self.comparedTo = comparedTo
        self.servers = servers
    }
}

public struct StatsResponse: Codable, Equatable, Sendable {
    public let updatedAt: Int
    public let totalPlayers: Int
    public let totalServers: Int

    public init(updatedAt: Int, totalPlayers: Int, totalServers: Int) {
        self.updatedAt = updatedAt
        self.totalPlayers = totalPlayers
        self.totalServers = totalServers
    }
}

public struct GraphPoint: Codable, Equatable, Sendable, Identifiable {
    public let ts: Int
    public let players: Int

    public var id: Int { ts }
    public var date: Date { unixDate(ts) }

    public init(ts: Int, players: Int) {
        self.ts = ts
        self.players = players
    }

    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        ts = try container.decode(Int.self)
        players = try container.decode(Int.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try container.encode(ts)
        try container.encode(players)
    }
}

public struct Peak: Codable, Equatable, Sendable {
    public let players: Int
    public let ts: Int

    public init(players: Int, ts: Int) {
        self.players = players
        self.ts = ts
    }
}

public struct ServerDetail: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let ip: String
    public let players: Int
    public let maxPlayers: Int?
    public let motd: String
    public let categories: [String]
    public let author: String?
    public let firstSeen: Int

    public init(id: String, name: String, ip: String, players: Int, maxPlayers: Int?, motd: String, categories: [String], author: String?, firstSeen: Int) {
        self.id = id
        self.name = name
        self.ip = ip
        self.players = players
        self.maxPlayers = maxPlayers
        self.motd = motd
        self.categories = categories
        self.author = author
        self.firstSeen = firstSeen
    }
}

public struct ServerDetailResponse: Codable, Equatable, Sendable {
    public let updatedAt: Int
    public let server: ServerDetail
    public let range: GraphRange
    public let points: [GraphPoint]
    public let peak: Peak?

    public init(updatedAt: Int, server: ServerDetail, range: GraphRange, points: [GraphPoint], peak: Peak?) {
        self.updatedAt = updatedAt
        self.server = server
        self.range = range
        self.points = points
        self.peak = peak
    }
}
