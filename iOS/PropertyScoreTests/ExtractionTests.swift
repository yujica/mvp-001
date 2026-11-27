import XCTest
@testable import PropertyScore

final class ExtractionTests: XCTestCase {
    func testPromptKeepsLateFactsFromMultilineAndFlattenedListings() {
        let lines = [
            "青葉レジデンス",
            String(repeating: "周辺のご案内。", count: 350),
            "販売価格：2400万円",
            "最寄駅：青葉駅 徒歩18分",
            String(repeating: "お問い合わせはこちら。", count: 250),
            "修繕見込：100万円",
            "土地権利：所有権"
        ]
        for separator in ["\n", " "] {
            let text = lines.joined(separator: separator)
            let prompt = OnDeviceExtractor.promptText(from: text)

            XCTAssertLessThanOrEqual(prompt.utf16.count, 1700)
            XCTAssertTrue(prompt.hasPrefix("青葉レジデンス"))
            XCTAssertTrue(prompt.contains("販売価格：2400万円"))
            XCTAssertTrue(prompt.contains("最寄駅：青葉駅 徒歩18分"))
            XCTAssertTrue(prompt.contains("修繕見込：100万円"))
            XCTAssertTrue(prompt.contains("土地権利：所有権"))
        }
    }

    func testPromptPassesShortListingThroughUnchanged() {
        let text = "青葉レジデンス\n販売価格：2400万円"
        XCTAssertEqual(OnDeviceExtractor.promptText(from: text), text)
    }
}
