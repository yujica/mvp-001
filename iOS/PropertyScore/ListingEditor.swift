import SwiftUI

struct ListingEditor: View {
    let onAnalyze: (Listing) -> Void
    let warning: String?

    @State private var name: String
    @State private var values: [Field: String]
    @State private var rights: Rights
    @FocusState private var focus: Field?

    init(initial: Listing, warning: String?, onAnalyze: @escaping (Listing) -> Void) {
        self.onAnalyze = onAnalyze
        self.warning = warning
        _name = State(initialValue: initial.name)
        _rights = State(initialValue: initial.leasehold.map { $0 ? .leasehold : .owned } ?? .unknown)
        _values = State(initialValue: Dictionary(uniqueKeysWithValues: Field.allCases.compactMap { field in
            initial[keyPath: field.keyPath].flatMap { value in
                guard value.isFinite, value >= 0 else { return nil }
                return (field, value.formatted(.number.grouping(.never).precision(.fractionLength(0...6))))
            }
        }))
    }

    var body: some View {
        Form {
            if let warning {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Label(warning, systemImage: "exclamationmark.circle")
                            .foregroundStyle(.orange)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(Text(warning))
                            .accessibilityIdentifier("extraction-warning")
                        Text("読み取れた項目を確認し、残りは手入力してください。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Section {
                TextField("物件名（任意）", text: $name)
                    .accessibilityIdentifier("field-name")
                numeric(.price)
                numeric(.walking)
                numeric(.area)
                numeric(.age)
                Picker("土地権利", selection: $rights) {
                    ForEach(Rights.allCases) { Text($0.rawValue).tag($0) }
                }
                .accessibilityIdentifier("field-rights")
            } header: {
                Text("物件の概要")
            } footer: {
                Text("読み取った値を確認・修正してください。不明な項目は空欄のままにできます。")
            }

            Section {
                numeric(.rent)
                numeric(.costs)
                numeric(.renovation)
                numeric(.valuation)
            } header: {
                Text("家賃・費用・評価額")
            } footer: {
                Text("月額運営費にローン返済額は含めません。費用がない場合は 0 を入力してください。")
            }
        }
        .navigationTitle("物件データの確認")
        .navigationBarTitleDisplayMode(.inline)
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItem(placement: .keyboard) {
                Button("完了") { focus = nil }
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                focus = nil
                onAnalyze(listing)
            } label: {
                Label("スコアを計算", systemImage: "chart.bar.xaxis")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityIdentifier("calculate-score")
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(.bar)
            .disabled(values.values.contains { !$0.isEmpty && Self.number($0) == nil })
        }
    }

    private func numeric(_ field: Field) -> some View {
        let value = Binding(get: { values[field, default: ""] }, set: { values[field] = $0 })
        return HStack {
            Text(field.title)
            Spacer()
            TextField("未入力", text: value)
                .multilineTextAlignment(.trailing)
                .keyboardType(.decimalPad)
                .focused($focus, equals: field)
                .accessibilityLabel(field.title)
                .accessibilityIdentifier("field-" + field.rawValue)
            Text(field.unit)
                .foregroundStyle(.secondary)
        }
    }

    private var listing: Listing {
        var listing = Listing(name: name, leasehold: rights == .unknown ? nil : rights == .leasehold)
        for field in Field.allCases {
            listing[keyPath: field.keyPath] = values[field].flatMap(Self.number)
        }
        return listing
    }

    private static func number(_ input: String) -> Double? {
        var normalized = input.applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? input
        if let separator = Locale.current.decimalSeparator, separator != "." {
            normalized = normalized.replacingOccurrences(of: separator, with: ".")
        }
        guard let value = Double(normalized.trimmingCharacters(in: .whitespaces)), value.isFinite, value >= 0 else { return nil }
        return value
    }

    private enum Rights: String, CaseIterable, Identifiable {
        case unknown = "不明", owned = "所有権", leasehold = "借地権"
        var id: Self { self }
    }

    private enum Field: String, CaseIterable {
        case price, walking, area, age, rent, costs, renovation, valuation

        var title: String {
            switch self {
            case .price: "販売価格"
            case .walking: "駅徒歩"
            case .area: "専有面積"
            case .age: "築年数"
            case .rent: "月額家賃"
            case .costs: "月額運営費"
            case .renovation: "修繕見込額"
            case .valuation: "積算評価額"
            }
        }

        var unit: String {
            switch self {
            case .walking: "分"
            case .area: "㎡"
            case .age: "年"
            default: "万円"
            }
        }

        var keyPath: WritableKeyPath<Listing, Double?> {
            switch self {
            case .price: \.price
            case .walking: \.walkingMinutes
            case .area: \.area
            case .age: \.age
            case .rent: \.monthlyRent
            case .costs: \.monthlyCosts
            case .renovation: \.renovationCost
            case .valuation: \.assessedValue
            }
        }
    }
}
