import XCTest
@testable import MinehutKit

final class MOTDFormatterTests: XCTestCase {
    func testStripsMiniMessageTagsAndGradients() {
        let motd = "<b><gradient:#66ccff:#A8E6FF:#67CFFF>TECHMINES</b>\n<#3399ff>Box-PvP\n\n<#66ffff><b>» MINING"
        XCTAssertEqual(MOTDFormatter.plainText(motd), "TECHMINES\nBox-PvP\n\n» MINING")
    }

    func testStripsLegacySectionAndAmpersandCodes() {
        XCTAssertEqual(MOTDFormatter.plainText("§6§lGold §r&aGreen"), "Gold Green")
    }

    func testStripsHexColorCodes() {
        XCTAssertEqual(MOTDFormatter.plainText("§x§f§f§0§0§0§0Red &#00FF00Lime"), "Red Lime")
    }

    func testCollapsesBlankLinesAndTrims() {
        XCTAssertEqual(MOTDFormatter.plainText("\n\n  A  \n\n\n\nB\n\n"), "A\n\nB")
    }

    func testKeepsPlainAmpersandText() {
        XCTAssertEqual(MOTDFormatter.plainText("Tom & Jerry"), "Tom & Jerry")
    }
}
