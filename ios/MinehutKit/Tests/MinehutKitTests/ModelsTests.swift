import XCTest
@testable import MinehutKit

final class ModelsTests: XCTestCase {
    private let decoder = JSONDecoder()

    func testDecodesTop() throws {
        let top = try decoder.decode(TopResponse.self, from: Fixtures.data(Fixtures.top))
        XCTAssertEqual(top.updatedAt, 1789000200)
        XCTAssertEqual(top.servers.count, 2)
        XCTAssertEqual(top.servers[0], TopServer(id: "aaa", name: "TechMines", players: 239, maxPlayers: 300, change24h: 45))
        XCTAssertNil(top.servers[1].maxPlayers)
        XCTAssertNil(top.servers[1].change24h)
    }

    func testDecodesRisingReady() throws {
        let rising = try decoder.decode(RisingResponse.self, from: Fixtures.data(Fixtures.rising))
        XCTAssertEqual(rising.window, .oneHour)
        XCTAssertTrue(rising.ready)
        XCTAssertEqual(rising.comparedTo, 1788996600)
        XCTAssertEqual(rising.servers[0].pct, 195.0)
        XCTAssertNil(rising.servers[1].pct)
    }

    func testDecodesRisingNotReady() throws {
        let rising = try decoder.decode(RisingResponse.self, from: Fixtures.data(Fixtures.risingNotReady))
        XCTAssertEqual(rising.window, .day)
        XCTAssertFalse(rising.ready)
        XCTAssertEqual(rising.readyAt, 1789086600)
        XCTAssertTrue(rising.servers.isEmpty)
    }

    func testDecodesStats() throws {
        let stats = try decoder.decode(StatsResponse.self, from: Fixtures.data(Fixtures.stats))
        XCTAssertEqual(stats, StatsResponse(updatedAt: 1789000200, totalPlayers: 2352, totalServers: 972))
    }

    func testDecodesServerDetailWithPointArrays() throws {
        let detail = try decoder.decode(ServerDetailResponse.self, from: Fixtures.data(Fixtures.server))
        XCTAssertEqual(detail.range, .day)
        XCTAssertEqual(detail.server.ip, "techmines.minehut.gg")
        XCTAssertNil(detail.server.author)
        XCTAssertEqual(detail.points, [GraphPoint(ts: 1788999300, players: 230), GraphPoint(ts: 1789000200, players: 239)])
        XCTAssertEqual(detail.peak, Peak(players: 239, ts: 1789000200))
        XCTAssertEqual(detail.points[0].date, Date(timeIntervalSince1970: 1788999300))
    }

    func testGraphPointRoundTripsAsArray() throws {
        let data = try JSONEncoder().encode([GraphPoint(ts: 10, players: 3)])
        XCTAssertEqual(String(decoding: data, as: UTF8.self), "[[10,3]]")
    }

    func testRejectsUnknownWindow() {
        let json = Fixtures.risingNotReady.replacingOccurrences(of: "\"24h\"", with: "\"2h\"")
        XCTAssertThrowsError(try decoder.decode(RisingResponse.self, from: Fixtures.data(json)))
    }
}
