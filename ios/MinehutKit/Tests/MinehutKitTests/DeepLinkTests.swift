import XCTest
@testable import MinehutKit

final class DeepLinkTests: XCTestCase {
    func testParsesTabs() {
        XCTAssertEqual(AppRoute(url: URL(string: "minehutanalytics://rising")!), .rising)
        XCTAssertEqual(AppRoute(url: URL(string: "minehutanalytics://top")!), .top)
    }

    func testParsesServer() {
        XCTAssertEqual(
            AppRoute(url: URL(string: "minehutanalytics://server/666bf9e9d55ba45e1e946e0d")!),
            .server(id: "666bf9e9d55ba45e1e946e0d")
        )
    }

    func testRejectsOtherSchemesAndHosts() {
        XCTAssertNil(AppRoute(url: URL(string: "https://rising")!))
        XCTAssertNil(AppRoute(url: URL(string: "minehutanalytics://settings")!))
    }

    func testRejectsServerWithoutId() {
        XCTAssertNil(AppRoute(url: URL(string: "minehutanalytics://server")!))
        XCTAssertNil(AppRoute(url: URL(string: "minehutanalytics://server/")!))
    }

    func testRoundTrips() {
        for route in [AppRoute.rising, .top, .server(id: "abc123")] {
            XCTAssertEqual(AppRoute(url: route.url), route)
        }
    }
}
