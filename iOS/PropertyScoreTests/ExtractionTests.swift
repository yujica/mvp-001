import FoundationModels
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

    func testPromptKeepsValuesOnLinesAfterLateKeywords() {
        let facts = ["販売価格\n2,400万円", "専有面積\n\n34.8㎡"]
        let text = String(repeating: "周辺のご案内。", count: 350) + "\n" + facts.joined(separator: "\n")
        let prompt = OnDeviceExtractor.promptText(from: text)

        XCTAssertLessThanOrEqual(prompt.utf16.count, 1700)
        for fact in facts { XCTAssertTrue(prompt.contains(fact)) }
    }

    func testDecodeShiftJISFromMetaDeclarations() throws {
        for meta in [
            "<META CHARSET=Shift_JIS>",
            "<meta content='text/html; charset=Shift_JIS' http-equiv=\"Content-Type\">"
        ] {
            let html = "<html><head><!-- <meta charset=ISO-8859-1> -->\(meta)</head><body>価格 2400万円</body></html>"
            let bytes = try XCTUnwrap(html.data(using: .shiftJIS))

            let decoded = ListingPage.decode(bytes, httpCharset: nil, isHTML: true)
            XCTAssertEqual(ListingPage.visibleText(decoded), "価格 2400万円")
        }
    }

    func testDecodePrefersHTTPHeaderOverMeta() throws {
        let html = "<meta charset=ISO-8859-1><p>青葉レジデンス</p>"
        let bytes = try XCTUnwrap(html.data(using: .utf8))

        XCTAssertEqual(ListingPage.decode(bytes, httpCharset: "UTF-8", isHTML: true), html)
    }

    func testDecodeEUCJPFromMetaAndShiftJISWithoutDeclaration() throws {
        let html = "<meta charset=EUC-JP><p>青葉レジデンス</p>"
        let eucJP = try XCTUnwrap(html.data(using: .japaneseEUC))
        XCTAssertEqual(ListingPage.decode(eucJP, httpCharset: nil, isHTML: true), html)

        let text = "青葉レジデンス"
        let shiftJIS = try XCTUnwrap(text.data(using: .shiftJIS))
        XCTAssertEqual(ListingPage.decode(shiftJIS, httpCharset: nil, isHTML: false), text)
    }

    func testGenerationFailureLocalizesReasonAndRetainsPartialFields() {
        let partial = Listing(name: "青葉レジデンス", walkingMinutes: 5, leasehold: false)
        let error = LanguageModelSession.GenerationError.assetsUnavailable(.init(debugDescription: "fixture"))
        let failure = ListingExtractionFailure(error, partialListing: partial)

        XCTAssertEqual(failure.localizedDescription, "掲載情報を読み取れませんでした。理由：Apple Intelligence のモデルを読み込めませんでした。")
        XCTAssertEqual(failure.partialListing, partial)
        XCTAssertNil(failure.partialListing.price)
    }
}
