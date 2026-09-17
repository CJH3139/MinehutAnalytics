import Foundation
import XCTest
@testable import MinehutKit

final class ServerIconTests: XCTestCase {
    func testUsesOfficialArtworkAndRejectsInvalidKeys() {
        XCTAssertEqual(ServerIcon.url(for: "END_CRYSTAL")?.absoluteString,
                       "https://minehut-server-icons-live.s3.us-west-2.amazonaws.com/END_CRYSTAL.png")
        for key in [nil, "", "../secret", "https://example.com/icon.png", "A/B", "A?B"] as [String?] {
            XCTAssertNil(ServerIcon.url(for: key))
        }
    }

    func testRankingIconsAreOptionalForOlderResponses() throws {
        let legacy = try JSONDecoder().decode(TopResponse.self, from: Fixtures.data(Fixtures.top))
        XCTAssertNil(legacy.servers[0].icon)
        let top = TopServer(id: "a", name: "Alpha", players: 10, maxPlayers: nil, change24h: nil, icon: "END_CRYSTAL")
        XCTAssertEqual(try JSONDecoder().decode(TopServer.self, from: JSONEncoder().encode(top)).icon, "END_CRYSTAL")
        let rising = RisingServer(id: "a", name: "Alpha", players: 10, then: 5, gain: 5, pct: 100, icon: "DIAMOND")
        XCTAssertEqual(try JSONDecoder().decode(RisingServer.self, from: JSONEncoder().encode(rising)).icon, "DIAMOND")
        let detail = try JSONDecoder().decode(ServerDetailResponse.self, from: Fixtures.data(Fixtures.server))
        XCTAssertNil(detail.server.icon)
    }

    func testNewWindowsHaveDistinctRequestsAndLegacyWindowsStillDecode() throws {
        XCTAssertEqual(RisingWindow.appWindows.map(\.title), ["12h", "24h", "1 week"])
        let client = APIClient(baseURL: URL(string: "https://example.com")!)
        XCTAssertEqual(client.url(for: .rising(.twelveHours)).absoluteString, "https://example.com/v1/rising?window=12h")
        XCTAssertEqual(client.url(for: .rising(.week)).absoluteString, "https://example.com/v1/rising?window=7d")
        for window in RisingWindow.allCases {
            XCTAssertEqual(try JSONDecoder().decode(RisingWindow.self, from: JSONEncoder().encode(window)), window)
        }
    }

    func testSavedIconsSurviveRoundTripAndOlderWatchlistsStillOpen() throws {
        let old = Data(#"{"servers":[{"id":"a","name":"Alpha"}]}"#.utf8)
        var favorites = try JSONDecoder().decode(FavoriteCollection.self, from: old)
        XCTAssertNil(favorites.servers[0].icon)
        favorites.toggle(id: "b", name: "Beta", icon: "DIAMOND")
        let restored = try JSONDecoder().decode(FavoriteCollection.self, from: JSONEncoder().encode(favorites))
        XCTAssertEqual(restored.servers[1].icon, "DIAMOND")
    }
}
