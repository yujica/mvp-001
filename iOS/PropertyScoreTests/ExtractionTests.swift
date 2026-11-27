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

    func testPromptUnionsOverlappingAndAdjacentKeywordExcerpts() {
        let filler = String(repeating: "周辺のご案内。", count: 350)
        let adjacent = "参考価格\n1,100万円\n注記\n物件価格\n1,000万円"
        let overlapping = "参考価格\n2,500万円\n販売価格\n2,400万円"
        let text = [filler, adjacent, filler, overlapping].joined(separator: "\n")
        let prompt = OnDeviceExtractor.promptText(from: text)

        XCTAssertLessThanOrEqual(prompt.utf16.count, 1700)
        XCTAssertTrue(prompt.contains(adjacent))
        XCTAssertTrue(prompt.contains(overlapping))
    }

    func testPromptFillsRemainingBudgetInSourceOrderWithoutDuplicatingExcerpts() {
        let prefix = String(repeating: "あ", count: 300) + "早めの紹介情報\n"
        let middle = "販売価格：2,400万円\n次の紹介情報\n"
        let detail = "専有面積：34.8㎡"
        let text = prefix + middle + String(repeating: "周辺のご案内。", count: 350) + "\n" + detail
        let prompt = OnDeviceExtractor.promptText(from: text)

        XCTAssertEqual(prompt.utf16.count, 1700)
        XCTAssertTrue(prompt.hasPrefix(prefix + middle))
        XCTAssertTrue(prompt.hasSuffix(detail))
        XCTAssertEqual(prompt.components(separatedBy: "販売価格").count, 2)
    }

    func testPromptKeepsKeywordPiecesFromOversizedMergedExcerpt() {
        let filler = String(repeating: "あ", count: 2000)
        let label = "販売価格\n"
        let piece = label + String(repeating: "🏠", count: 21) + "円\n"
        let text = filler + "\n" + String(repeating: piece, count: 40)
        let prompt = OnDeviceExtractor.promptText(from: text)

        XCTAssertEqual(prompt.utf16.count, 1700)
        XCTAssertTrue(prompt.hasSuffix("\n" + String(repeating: piece, count: 29) + label + String(repeating: "🏠", count: 16)))
    }

    func testPromptSharesBudgetAcrossKeywordFieldsBeforeRepeatingAnyField() {
        let filler = String(repeating: "周辺のご案内。", count: 350)
        let price = "販売価格\n2,400万円"
        let prices = String(repeating: price + "\n", count: 150)
        let facts = ["家賃\n月額8万円", "最寄駅\n青葉駅から徒歩7分", "賃料\n月額9万円"]
        let text = ([filler, prices] + facts).joined(separator: "\n" + filler + "\n")
        let prompt = OnDeviceExtractor.promptText(from: text)

        XCTAssertLessThanOrEqual(prompt.utf16.count, 1700)
        for fact in [price] + facts { XCTAssertTrue(prompt.contains(fact), fact) }
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

    func testDecodeUTF8BOMOverridesHTTPAndMetaCharsets() {
        let html = "<meta charset=Shift_JIS><p>青葉レジデンス</p>"
        let bytes = Data([0xEF, 0xBB, 0xBF]) + Data(html.utf8)

        XCTAssertEqual(ListingPage.decode(bytes, httpCharset: "ISO-8859-1", isHTML: true), html)
        XCTAssertEqual(ListingPage.decode(bytes, httpCharset: nil, isHTML: true), html)
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

        XCTAssertEqual(failure.localizedDescription, "掲載情報を読み取れませんでした。理由：Apple Intelligence のモデルを読み込めませんでした。「設定」＞「Apple IntelligenceとSiri」を開き、モデルが未ダウンロードの場合は完了を待ってからお試しください。")
        XCTAssertEqual(failure.partialListing, partial)
        XCTAssertNil(failure.partialListing.price)
    }

    func testGenerationErrorsShowSpecificReasonsAndNextSteps() {
        typealias GenerationError = LanguageModelSession.GenerationError
        let context = GenerationError.Context(debugDescription: "fixture")
        let cases: [(GenerationError, String, String)] = [
            (.exceededContextWindowSize(context), "掲載文が長すぎます", "物件情報の部分だけを貼り付けて"),
            (.guardrailViolation(context), "安全性チェックにより読み取りが停止", "物件情報を手入力"),
            (.unsupportedGuide(context), "読み取り形式に対応していません", "物件情報を手入力"),
            (.unsupportedLanguageOrLocale(context), "端末の言語設定にモデルが対応していません", "Apple Intelligence の言語設定を確認"),
            (.decodingFailure(context), "モデルの応答から物件データを読み取れません", "物件情報を手入力"),
            (.rateLimited(context), "利用回数が一時的に制限", "しばらく待って"),
            (.concurrentRequests(context), "別の読み取りを処理中", "その処理が終わってから"),
            (.refusal(.init(transcriptEntries: []), context), "掲載文の読み取りを拒否", "物件情報を手入力")
        ]
        for (error, reason, nextStep) in cases {
            let message = ListingExtractionFailure(error).reason
            XCTAssertTrue(message.contains(reason), message)
            XCTAssertTrue(message.contains(nextStep), message)
        }
    }

    func testUnknownExtractionErrorUsesLocalizedDescription() {
        let error = NSError(domain: "ExtractionTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "予期しないエラー"])

        XCTAssertEqual(ListingExtractionFailure(error).reason, error.localizedDescription)
    }

    func testBridgedModelErrorsShowExecutionGuidanceInsteadOfRawDescription() {
        let errors = [
            NSError(domain: "FoundationModels.LanguageModelSession.GenerationError", code: -1),
            NSError(domain: "com.apple.FoundationModels", code: 123),
            NSError(domain: "LanguageModelSession.GenerationError", code: 123)
        ]
        let expected = "端末内AI（Apple Intelligence）がこの環境でモデルを実行できませんでした。Apple Intelligenceを有効にした対応端末で再試行するか、下の項目を手入力してください。"
        for error in errors {
            XCTAssertEqual(ListingExtractionFailure(error).reason, expected)
        }

        let intermediate = NSError(domain: "ExtractionTests", code: 1, userInfo: [NSUnderlyingErrorKey: errors[0]])
        let other = NSError(domain: "ExtractionTests", code: 2)
        let wrapped = NSError(domain: "ExtractionTests", code: 3, userInfo: [NSMultipleUnderlyingErrorsKey: [other, intermediate]])
        XCTAssertEqual(ListingExtractionFailure(wrapped).reason, expected)
    }

    func testWrappedTypedModelErrorKeepsSpecificGuidance() {
        let error = LanguageModelSession.GenerationError.exceededContextWindowSize(.init(debugDescription: "fixture"))
        let wrapped = NSError(domain: "ExtractionTests", code: 1, userInfo: [NSUnderlyingErrorKey: error])

        XCTAssertTrue(ListingExtractionFailure(wrapped).reason.contains("掲載文が長すぎます"))
    }

    func testModelAvailabilityShowsSpecificReasonsAndNextSteps() throws {
        let cases: [(SystemLanguageModel.Availability, String, String)] = [
            (.unavailable(.deviceNotEligible), "対応していません", "対応端末をお使いください"),
            (.unavailable(.appleIntelligenceNotEnabled), "オフになっています", "「Apple IntelligenceとSiri」で有効"),
            (.unavailable(.modelNotReady), "モデルは準備中です", "ダウンロード状況を確認")
        ]
        XCTAssertNil(OnDeviceExtractor.unavailableReason(for: .available))
        for (availability, reason, nextStep) in cases {
            let message = try XCTUnwrap(OnDeviceExtractor.unavailableReason(for: availability))
            XCTAssertTrue(message.contains(reason), message)
            XCTAssertTrue(message.contains(nextStep), message)
        }
    }
}
