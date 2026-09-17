import XCTest
@testable import MinehutKit

final class AnalyticsTests: XCTestCase {
    func testOverviewContractAndNullBaseline() throws {
        let json = #"{"updatedAt":100,"totalPlayers":80,"totalServers":20,"listedPlayers":60,"activeServers":10,"playersChange24h":null,"serverChange24h":-2,"top10Share":50.0,"points":[{"ts":100,"players":80,"servers":20}],"categories":[{"name":"Survival","players":60,"servers":10}]}"#
        let value = try JSONDecoder().decode(OverviewResponse.self, from: Data(json.utf8))
        XCTAssertNil(value.playersChange24h)
        XCTAssertEqual(value.points[0].players, 80)
        XCTAssertEqual(value.categories[0].name, "Survival")
        let client = APIClient(baseURL: URL(string: "https://example.com")!)
        XCTAssertEqual(client.url(for: .overview(.week)).absoluteString, "https://example.com/v1/overview?range=7d")
        XCTAssertNotEqual(APIClient.Endpoint.overview(.week).cacheKey, APIClient.Endpoint.overview(.day).cacheKey)
    }

    func testStatisticsSortAndDoNotInventEmptyValues() {
        XCTAssertNil(ObservationStatistics(points: []).mean)
        XCTAssertNil(ObservationStatistics(points: [.init(ts: 1, players: 5)]).change)
        let stats = ObservationStatistics(points: [.init(ts: 3, players: 12), .init(ts: 1, players: 4), .init(ts: 2, players: 8)])
        XCTAssertEqual(stats.mean, 8)
        XCTAssertEqual(stats.change, 8)
        XCTAssertEqual(stats.peak, 12)
    }

    func testComparisonUsesSharedTimeBoundsWithoutInventingSamples() {
        let result = ComparisonObservations(first: [.init(ts: 1, players: 9), .init(ts: 3, players: 8)], second: [.init(ts: 2, players: 4), .init(ts: 4, players: 5)])
        XCTAssertEqual(result.first.map(\.ts), [3])
        XCTAssertEqual(result.second.map(\.ts), [2])
        XCTAssertEqual(result.start, 2)
        XCTAssertEqual(result.end, 3)
        XCTAssertTrue(ComparisonObservations(first: [], second: [.init(ts: 2, players: 4)]).second.isEmpty)
    }

    func testFavoritesRoundTripAndToggleWithoutDuplicates() throws {
        var favorites = FavoriteCollection()
        favorites.toggle(id: "alpha", name: "Alpha")
        favorites.toggle(id: "beta", name: "Beta")
        favorites.toggle(id: "alpha", name: "Alpha")
        let restored = try JSONDecoder().decode(FavoriteCollection.self, from: JSONEncoder().encode(favorites))
        XCTAssertEqual(restored.servers.map(\.id), ["beta"])
    }
}
