import XCTest

@MainActor
final class PropertyScoreUITests: XCTestCase {
    func testPasteReviewAndScoreWithExclusion() {
        let app = launch("-ui-fixture")
        capture("01-input", in: app)

        app.buttons["掲載文"].tap()
        let editor = app.textViews["listing-text"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()
        editor.typeText("Aoba Residence 2400 18 min walk")
        app.buttons["完了"].tap()
        app.buttons["extract-listing"].tap()

        let name = app.textFields["field-name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        XCTAssertEqual(name.value as? String, "青葉レジデンス")
        capture("02-review", in: app)
        app.buttons["calculate-score"].tap()
        let total = app.staticTexts["total-score"]
        XCTAssertTrue(total.waitForExistence(timeout: 5))
        XCTAssertEqual(total.label, "70")
        XCTAssertTrue(app.descendants(matching: .any)["excluded-result"].firstMatch.exists)
        XCTAssertTrue(app.staticTexts["駅徒歩が15分を超えています"].exists)
        capture("03-result", in: app)
    }

    func testManualEntryWhenModelIsUnavailable() {
        let app = launch("-ui-model-unavailable")
        XCTAssertTrue(app.descendants(matching: .any)["model-status"].firstMatch.exists)
        app.buttons["manual-listing"].tap()
        let walking = app.textFields["field-walking"]
        XCTAssertTrue(walking.waitForExistence(timeout: 5))
        walking.tap()
        walking.typeText("5")
        app.buttons["完了"].tap()
        app.buttons["calculate-score"].tap()
        let total = app.staticTexts["total-score"]
        XCTAssertTrue(total.waitForExistence(timeout: 5))
        XCTAssertEqual(total.label, "17")
        XCTAssertTrue(app.staticTexts["暫定スコア：未評価の項目は加点していません。"].exists)
    }

    func testExtractionFailureShowsReasonAndKeepsPartialListingForManualScoring() {
        let app = launch("-ui-model-failure")
        app.buttons["掲載文"].tap()
        let editor = app.textViews["listing-text"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()
        editor.typeText("Aoba Residence 5 min walk")
        app.buttons["完了"].tap()
        app.buttons["extract-listing"].tap()

        let warning = app.descendants(matching: .any)["extraction-warning"].firstMatch
        XCTAssertTrue(warning.waitForExistence(timeout: 5))
        XCTAssertTrue(warning.label.contains("Apple Intelligence のモデルを読み込めませんでした。"))
        XCTAssertEqual(app.textFields["field-name"].value as? String, "青葉レジデンス")
        XCTAssertEqual(app.textFields["field-walking"].value as? String, "5")
        app.buttons["calculate-score"].tap()
        let total = app.staticTexts["total-score"]
        XCTAssertTrue(total.waitForExistence(timeout: 5))
        XCTAssertEqual(total.label, "17")
    }

    func testConditionsAreSavedAcrossLaunches() {
        let app = launch("-ui-fixture")
        app.buttons["open-conditions"].tap()
        let leasehold = app.switches["exclude-leasehold"]
        XCTAssertTrue(leasehold.waitForExistence(timeout: 5))
        XCTAssertEqual(leasehold.value as? String, "1")
        leasehold.coordinate(withNormalizedOffset: CGVector(dx: 0.94, dy: 0.5)).tap()
        XCTAssertEqual(leasehold.value as? String, "0")
        capture("04-conditions", in: app)
        app.buttons["save-conditions"].tap()
        XCTAssertTrue(app.buttons["open-conditions"].waitForExistence(timeout: 5))

        app.terminate()
        app.launch()
        app.buttons["open-conditions"].tap()
        XCTAssertTrue(leasehold.waitForExistence(timeout: 5))
        XCTAssertEqual(leasehold.value as? String, "0")
    }

    private func launch(_ mode: String) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = [mode, "-ui-defaults-suite", "PropertyScoreTests." + UUID().uuidString]
        app.launch()
        return app
    }

    private func capture(_ name: String, in app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
