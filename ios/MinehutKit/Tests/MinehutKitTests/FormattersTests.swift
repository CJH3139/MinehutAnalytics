import XCTest
@testable import MinehutKit

final class FormattersTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_789_000_200)

    func testGain() {
        XCTAssertEqual(Formatters.gain(78, pct: 195.0), "+78 (↑195%)")
        XCTAssertEqual(Formatters.gain(4, pct: 133.3), "+4 (↑133%)")
        XCTAssertEqual(Formatters.gain(1, pct: 99.5), "+1 (↑100%)")
        XCTAssertEqual(Formatters.gain(12, pct: nil), "+12 (new)")
    }

    func testChange() {
        XCTAssertEqual(Formatters.change(5), "+5")
        XCTAssertEqual(Formatters.change(-3), "-3")
        XCTAssertEqual(Formatters.change(0), "0")
        XCTAssertEqual(Formatters.change(nil), "")
    }

    func testPlayers() {
        XCTAssertEqual(Formatters.players(239, max: 300), "239 / 300")
        XCTAssertEqual(Formatters.players(239, max: nil), "239")
        XCTAssertEqual(Formatters.players(5, max: 0), "5")
    }

    func testRelative() {
        XCTAssertEqual(Formatters.relative(from: 1_789_000_200 - 30, now: now), "just now")
        XCTAssertEqual(Formatters.relative(from: 1_789_000_200 - 300, now: now), "5m ago")
        XCTAssertEqual(Formatters.relative(from: 1_789_000_200 - 7200, now: now), "2h ago")
        XCTAssertEqual(Formatters.relative(from: 1_789_000_200 - 172_800, now: now), "2d ago")
        XCTAssertEqual(Formatters.relative(from: 1_789_000_200 + 500, now: now), "just now")
    }

    func testUpdated() {
        XCTAssertEqual(Formatters.updated(1_789_000_200 - 300, now: now), "Updated 5m ago")
    }

    func testClockTime() {
        let text = Formatters.clockTime(1_789_000_200, timeZone: TimeZone(identifier: "UTC")!, locale: Locale(identifier: "en_US_POSIX"))
        XCTAssertTrue(text.contains("12:30"), text)
    }
}
