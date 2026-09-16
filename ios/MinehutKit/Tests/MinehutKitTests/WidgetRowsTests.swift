import XCTest
@testable import MinehutKit

final class WidgetRowsTests: XCTestCase {
    private let decoder = JSONDecoder()

    func testRisingRows() throws {
        let rising = try decoder.decode(RisingResponse.self, from: Fixtures.data(Fixtures.rising))
        let content = WidgetContent.rising(rising, limit: 8)
        XCTAssertEqual(content.kind, .rising)
        XCTAssertTrue(content.ready)
        XCTAssertEqual(content.updatedAt, 1789000200)
        XCTAssertEqual(content.rows, [
            WidgetRow(id: "bbb", rank: 1, name: "MineRefine", players: 118, delta: "+78 (↑195%)", shortDelta: "+78"),
            WidgetRow(id: "ccc", rank: 2, name: "FreshSMP", players: 12, delta: "+12 (new)", shortDelta: "+12"),
        ])
        XCTAssertEqual(content.inlineText, "↑ MineRefine +78")
    }

    func testRisingLimit() throws {
        let rising = try decoder.decode(RisingResponse.self, from: Fixtures.data(Fixtures.rising))
        XCTAssertEqual(WidgetContent.rising(rising, limit: 1).rows.map(\.id), ["bbb"])
    }

    func testRisingNotReady() throws {
        let rising = try decoder.decode(RisingResponse.self, from: Fixtures.data(Fixtures.risingNotReady))
        let content = WidgetContent.rising(rising, limit: 8)
        XCTAssertFalse(content.ready)
        XCTAssertTrue(content.rows.isEmpty)
        XCTAssertEqual(content.inlineText, "Collecting data")
    }

    func testRisingReadyButEmpty() {
        let empty = RisingResponse(updatedAt: 1, window: .day, ready: true, readyAt: nil, comparedTo: 0, servers: [])
        XCTAssertEqual(WidgetContent.rising(empty, limit: 8).inlineText, "No risers right now")
    }

    func testTopRows() throws {
        let top = try decoder.decode(TopResponse.self, from: Fixtures.data(Fixtures.top))
        let content = WidgetContent.top(top, limit: 4)
        XCTAssertEqual(content.kind, .top)
        XCTAssertTrue(content.ready)
        XCTAssertEqual(content.rows, [
            WidgetRow(id: "aaa", rank: 1, name: "TechMines", players: 239, delta: "+45", shortDelta: "+45"),
            WidgetRow(id: "bbb", rank: 2, name: "MineRefine", players: 118, delta: "", shortDelta: ""),
        ])
        XCTAssertEqual(content.inlineText, "#1 TechMines 239")
    }

    func testTopSeriesRowsAndLines() throws {
        let response = try decoder.decode(TopSeriesResponse.self, from: Fixtures.data(Fixtures.topSeries))
        let content = WidgetContent.topSeries(response, limit: 8)
        XCTAssertEqual(content.kind, .top)
        XCTAssertTrue(content.ready)
        XCTAssertEqual(content.rows, [
            WidgetRow(id: "aaa", rank: 1, name: "TechMines", players: 239, delta: "+45", shortDelta: "+45"),
            WidgetRow(id: "bbb", rank: 2, name: "MineRefine", players: 118, delta: "", shortDelta: ""),
        ])
        XCTAssertEqual(content.series.map(\.id), ["aaa", "bbb"])
        XCTAssertEqual(content.series.map(\.colorIndex), [0, 1])
        XCTAssertEqual(
            content.series[0].points,
            [GraphPoint(ts: 1788999300, players: 230), GraphPoint(ts: 1789000200, players: 239)]
        )
        XCTAssertTrue(content.series[1].points.isEmpty)
        XCTAssertEqual(content.inlineText, "#1 TechMines 239")
    }

    func testTopSeriesRespectsLimit() throws {
        let response = try decoder.decode(TopSeriesResponse.self, from: Fixtures.data(Fixtures.topSeries))
        let content = WidgetContent.topSeries(response, limit: 1)
        XCTAssertEqual(content.rows.map(\.id), ["aaa"])
        XCTAssertEqual(content.series.map(\.id), ["aaa"])
    }

    func testPlainTopCarriesNoSeries() throws {
        let top = try decoder.decode(TopResponse.self, from: Fixtures.data(Fixtures.top))
        XCTAssertTrue(WidgetContent.top(top, limit: 4).series.isEmpty)
    }

    func testTopEmpty() {
        XCTAssertEqual(WidgetContent.top(TopResponse(updatedAt: 1, servers: []), limit: 4).inlineText, "No servers online")
    }
}
