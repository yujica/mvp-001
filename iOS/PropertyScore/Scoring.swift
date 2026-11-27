import Foundation

enum Category: String, CaseIterable, Identifiable, Codable {
    case location, building, capex, income, interest, valuation

    var id: String { rawValue }

    var title: String {
        switch self {
        case .location: "立地"
        case .building: "建物性能"
        case .capex: "CAPEX"
        case .income: "家賃・収支"
        case .interest: "金利耐性"
        case .valuation: "積算"
        }
    }

    var defaultWeight: Int {
        switch self {
        case .location, .income: 20
        default: 15
        }
    }
}

struct Listing: Hashable {
    var name: String = ""
    var price: Double?
    var monthlyRent: Double?
    var monthlyCosts: Double?
    var walkingMinutes: Double?
    var area: Double?
    var age: Double?
    var renovationCost: Double?
    var assessedValue: Double?
    var leasehold: Bool?
}

struct Conditions: Codable, Equatable {
    var maxWalkingMinutes = 15
    var minArea = 20
    var excludeLeasehold = true
    var loanToValue = 80
    var loanYears = 30
    var stressRate = 5.0
    var weights = Dictionary(uniqueKeysWithValues: Category.allCases.map { ($0, $0.defaultWeight) })

    func weight(_ category: Category) -> Int {
        min(max(weights[category] ?? category.defaultWeight, 0), 100)
    }
}

struct Score {
    struct Metric: Identifiable {
        let category: Category
        let fraction: Double?
        let maxPoints: Double
        let detail: String

        var id: Category { category }
        var points: Double? { fraction.map { $0 * maxPoints } }
    }

    let metrics: [Metric]
    let exclusions: [String]
    let uncheckedConditions: [String]

    var availablePoints: Double { metrics.compactMap(\.points).reduce(0, +) }
    var total: Int? { metrics.contains(where: { $0.points != nil && $0.maxPoints > 0 }) ? Int(availablePoints.rounded()) : nil }
    var provisional: Bool { metrics.contains { $0.maxPoints > 0 && $0.fraction == nil } }
}

enum Scoring {
    static func evaluate(_ listing: Listing, _ conditions: Conditions) -> Score {
        var exclusions: [String] = []
        var unchecked: [String] = []
        let walkingLimit = Double(max(conditions.maxWalkingMinutes, 1))
        let areaMinimum = Double(max(conditions.minArea, 1))

        if let minutes = nonnegative(listing.walkingMinutes) {
            if minutes > walkingLimit { exclusions.append("駅徒歩が\(Int(walkingLimit))分を超えています") }
        } else {
            unchecked.append("駅徒歩")
        }
        if let area = positive(listing.area) {
            if area < areaMinimum { exclusions.append("専有面積が\(Int(areaMinimum))㎡未満です") }
        } else {
            unchecked.append("専有面積")
        }
        if conditions.excludeLeasehold {
            if listing.leasehold == true { exclusions.append("借地権の物件です") }
            if listing.leasehold == nil { unchecked.append("土地権利") }
        }

        let price = positive(listing.price)
        let net = nonnegative(listing.monthlyRent).flatMap { rent in nonnegative(listing.monthlyCosts).map { rent - $0 } }
        let totalWeight = Category.allCases.reduce(0) { $0 + conditions.weight($1) }
        let metrics = Category.allCases.map { category -> Score.Metric in
            let fraction: Double?
            let detail: String
            switch category {
            case .location:
                fraction = nonnegative(listing.walkingMinutes).map { 1 - $0 / (walkingLimit * 2) }
                detail = "駅徒歩を上限条件に対して評価"
            case .building:
                fraction = nonnegative(listing.age).map { 1 - $0 / 50 }
                detail = "築年数を評価（築50年以上は0点）"
            case .capex:
                fraction = ratio(nonnegative(listing.renovationCost), price).map { 1 - $0 / 0.15 }
                detail = "修繕見込額の価格比（15％以上は0点）"
            case .income:
                fraction = ratio(net.map { $0 * 12 }, price).map { $0 / 0.08 }
                detail = "年間手取り収支の価格比（8％以上で満点）"
            case .interest:
                if let price, let net {
                    let principal = price * Double(min(max(conditions.loanToValue, 0), 100)) / 100
                    let months = Double(min(max(conditions.loanYears, 1), 50) * 12)
                    let rate = min(max(conditions.stressRate.isFinite ? conditions.stressRate : 0, 0), 30) / 1200
                    let payment = rate == 0 ? principal / months : principal * rate / (1 - pow(1 + rate, -months))
                    fraction = payment > 0 ? net / payment / 1.5 : (net >= 0 ? 1 : 0)
                } else {
                    fraction = nil
                }
                detail = "想定金利での元利均等返済に対する月間手取り（1.5倍以上で満点）"
            case .valuation:
                fraction = ratio(nonnegative(listing.assessedValue), price)
                detail = "積算評価額の価格比（100％以上で満点）"
            }
            let maxPoints = totalWeight > 0 ? Double(conditions.weight(category)) / Double(totalWeight) * 100 : 0
            return Score.Metric(category: category, fraction: fraction.map { min(max($0, 0), 1) }, maxPoints: maxPoints, detail: detail)
        }
        return Score(metrics: metrics, exclusions: exclusions, uncheckedConditions: unchecked)
    }

    private static func ratio(_ numerator: Double?, _ denominator: Double?) -> Double? {
        guard let numerator, let denominator else { return nil }
        return numerator / denominator
    }

    private static func nonnegative(_ value: Double?) -> Double? {
        guard let value, value.isFinite, value >= 0 else { return nil }
        return value
    }

    private static func positive(_ value: Double?) -> Double? {
        guard let value = nonnegative(value), value > 0 else { return nil }
        return value
    }
}
