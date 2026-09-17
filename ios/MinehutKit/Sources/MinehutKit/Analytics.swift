import Foundation

public struct OverviewResponse: Codable, Equatable, Sendable {
    public let updatedAt: Int
    public let totalPlayers: Int
    public let totalServers: Int
    public let listedPlayers: Int
    public let activeServers: Int
    public let playersChange24h: Int?
    public let serverChange24h: Int?
    public let top10Share: Double?
    public let points: [NetworkPoint]
    public let categories: [NetworkCategory]
}

public struct NetworkPoint: Codable, Equatable, Sendable {
    public let ts: Int
    public let players: Int
    public let servers: Int
}

public struct NetworkCategory: Codable, Equatable, Sendable, Identifiable {
    public var id: String { name }
    public let name: String
    public let players: Int
    public let servers: Int
}

public struct ObservationStatistics: Equatable, Sendable {
    public let count: Int
    public let mean: Double?
    public let peak: Int?
    public let minimum: Int?
    public let change: Int?
    public init(points: [GraphPoint]) {
        let sorted = points.sorted { $0.ts < $1.ts }
        count = sorted.count
        mean = sorted.isEmpty ? nil : sorted.reduce(0.0) { $0 + Double($1.players) } / Double(sorted.count)
        peak = sorted.map(\.players).max()
        minimum = sorted.map(\.players).min()
        change = sorted.count > 1 ? sorted.last!.players - sorted.first!.players : nil
    }
}

public struct ComparisonObservations: Sendable {
    public let first: [GraphPoint]
    public let second: [GraphPoint]
    public let start: Int?
    public let end: Int?
    public init(first: [GraphPoint], second: [GraphPoint]) {
        guard let a = first.map(\.ts).min(), let b = second.map(\.ts).min(),
              let c = first.map(\.ts).max(), let d = second.map(\.ts).max(), max(a, b) <= min(c, d) else {
            self.first = []; self.second = []; start = nil; end = nil
            return
        }
        let lower = max(a, b), upper = min(c, d)
        start = lower; end = upper
        self.first = first.filter { (lower...upper).contains($0.ts) }.sorted { $0.ts < $1.ts }
        self.second = second.filter { (lower...upper).contains($0.ts) }.sorted { $0.ts < $1.ts }
    }
}

public struct FavoriteServer: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let name: String
}

public struct FavoriteCollection: Codable, Equatable, Sendable {
    public private(set) var servers: [FavoriteServer] = []
    public init() {}
    public func contains(_ id: String) -> Bool { servers.contains { $0.id == id } }
    public mutating func toggle(id: String, name: String) {
        if contains(id) { servers.removeAll { $0.id == id } }
        else { servers.append(FavoriteServer(id: id, name: name)) }
    }
}
