import SwiftUI

struct ConditionsView: View {
    let onSave: (Conditions) -> Void
    @State private var draft: Conditions

    init(initial: Conditions, onSave: @escaping (Conditions) -> Void) {
        _draft = State(initialValue: initial)
        self.onSave = onSave
    }

    var body: some View {
        Form {
            Section("即除外条件") {
                Stepper(value: $draft.maxWalkingMinutes, in: 1...60) {
                    Text("駅徒歩：\(draft.maxWalkingMinutes)分以内")
                        .accessibilityIdentifier("walking-condition")
                }
                Stepper(value: $draft.minArea, in: 1...300) {
                    Text("専有面積：\(draft.minArea)㎡以上")
                }
                Toggle("借地権を除外", isOn: $draft.excludeLeasehold)
                    .accessibilityIdentifier("exclude-leasehold")
            }
            Section("ローン試算") {
                Stepper("借入割合：\(draft.loanToValue)％", value: $draft.loanToValue, in: 0...100, step: 5)
                Stepper("返済期間：\(draft.loanYears)年", value: $draft.loanYears, in: 1...50)
                Stepper(value: $draft.stressRate, in: 0...30, step: 0.5) {
                    Text("想定金利：\(draft.stressRate, format: .number.precision(.fractionLength(1)))％")
                }
            }
            Section {
                ForEach(Category.allCases) { category in
                    Stepper("\(category.title)：\(draft.weight(category))", value: weight(category), in: 0...100)
                }
            } header: {
                Text("評価の重み")
            } footer: {
                Text("重みは比率として使い、合計を100点に換算します。0の項目は総合スコアに含めません。")
            }
        }
        .navigationTitle("分析条件")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") { onSave(draft) }
                    .accessibilityIdentifier("save-conditions")
                    .disabled(Category.allCases.allSatisfy { draft.weight($0) == 0 })
            }
        }
    }

    private func weight(_ category: Category) -> Binding<Int> {
        Binding(get: { draft.weight(category) }, set: { draft.weights[category] = $0 })
    }
}
