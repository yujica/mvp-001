import XCTest
@testable import PropertyScore

final class ScoringTests: XCTestCase {
    func testCompleteListingHasSixMetricsAndWeightedTotal() {
        let listing = Listing(price: 2400, monthlyRent: 16, monthlyCosts: 3, walkingMinutes: 18,
                              area: 35, age: 12, renovationCost: 100, assessedValue: 1800, leasehold: false)
        let score = Scoring.evaluate(listing, Conditions())

        XCTAssertEqual(score.metrics.map(\.category), Category.allCases)
        XCTAssertEqual(score.metrics.reduce(0) { $0 + $1.maxPoints }, 100, accuracy: 0.0001)
        XCTAssertEqual(score.total, 70)
        XCTAssertFalse(score.provisional)
        XCTAssertEqual(score.exclusions, ["駅徒歩が15分を超えています"])
    }

    func testExclusionBoundariesAndDisabledLeaseholdRule() {
        var conditions = Conditions()
        let listing = Listing(walkingMinutes: 15, area: 20, leasehold: true)
        XCTAssertEqual(Scoring.evaluate(listing, conditions).exclusions, ["借地権の物件です"])
        conditions.excludeLeasehold = false
        XCTAssertTrue(Scoring.evaluate(listing, conditions).exclusions.isEmpty)
        XCTAssertEqual(Scoring.evaluate(Listing(walkingMinutes: 16, area: 19), conditions).exclusions.count, 2)
    }

    func testMissingDataDoesNotPassExclusionsOrEarnPoints() {
        let score = Scoring.evaluate(Listing(), Conditions())

        XCTAssertNil(score.total)
        XCTAssertTrue(score.provisional)
        XCTAssertEqual(score.uncheckedConditions, ["駅徒歩", "専有面積", "土地権利"])
    }

    func testAdjustedWeightsAndZeroRateLoan() {
        var conditions = Conditions()
        conditions.weights = Dictionary(uniqueKeysWithValues: Category.allCases.map { ($0, $0 == .interest ? 50 : 0) })
        conditions.stressRate = 0
        conditions.loanToValue = 100
        conditions.loanYears = 10
        let good = Scoring.evaluate(Listing(price: 1200, monthlyRent: 20, monthlyCosts: 5), conditions)
        let under = Scoring.evaluate(Listing(price: 1200, monthlyRent: 10, monthlyCosts: 5), conditions)

        XCTAssertEqual(good.total, 100)
        XCTAssertFalse(good.provisional)
        XCTAssertEqual(under.total, 33)
    }

    func testListingHTMLRemovesExecutableMarkupAndDecodesEntities() {
        let markup = "<html><nav>Menu</nav><script>noise</script><h1>青葉 &amp; 桜</h1><p>価格&nbsp;2400万円</p></html>"
        XCTAssertEqual(ListingPage.visibleText(markup), "青葉 & 桜 価格 2400万円")
    }
}
