import SwiftUI

struct ResultView: View {
    let listing: Listing
    let score: Score

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(listing.name.isEmpty ? "物件の評価" : listing.name)
                        .font(.title2.bold())
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(score.total.map(String.init) ?? "—")
                            .font(.system(size: 54, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.blue)
                            .monospacedDigit()
                            .accessibilityIdentifier("total-score")
                        Text("/ 100 点").font(.headline).foregroundStyle(.secondary)
                    }
                    if !score.exclusions.isEmpty {
                        Label("即除外", systemImage: "exclamationmark.triangle.fill")
                            .font(.headline)
                            .foregroundStyle(.red)
                            .accessibilityIdentifier("excluded-result")
                        ForEach(score.exclusions, id: \.self) { Text($0).font(.subheadline) }
                    } else if score.uncheckedConditions.isEmpty {
                        Label("即除外条件に該当なし", systemImage: "checkmark.circle")
                            .font(.headline)
                            .foregroundStyle(.green)
                            .accessibilityIdentifier("eligible-result")
                    } else {
                        Label("即除外は未確定", systemImage: "questionmark.circle")
                            .font(.headline)
                    }
                    if !score.uncheckedConditions.isEmpty {
                        Text("未判定：\(score.uncheckedConditions.joined(separator: "、"))")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    if score.provisional {
                        Text("暫定スコア：未評価の項目は加点していません。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .scorePanel()

                VStack(alignment: .leading, spacing: 10) {
                    Text("6つの評価軸").font(.headline).accessibilityAddTraits(.isHeader)
                    RadarChart(metrics: score.metrics)
                    ForEach(score.metrics) { metric in
                        Divider()
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(metric.category.title).font(.subheadline.bold())
                                Spacer()
                                if let points = metric.points {
                                    Text("\(points, format: .number.precision(.fractionLength(0...1))) / \(metric.maxPoints, format: .number.precision(.fractionLength(0...1))) 点")
                                        .font(.subheadline.monospacedDigit())
                                } else {
                                    Text("未評価").font(.subheadline).foregroundStyle(.secondary)
                                }
                            }
                            Text(metric.detail).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .scorePanel()

                Text("この結果は入力値に基づく参考試算です。実際の条件や費用を確認してください。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(20)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("分析結果")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct RadarChart: View {
    let metrics: [Score.Metric]

    var body: some View {
        Canvas { context, size in
            guard !metrics.isEmpty else { return }
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = max(0, min(size.width / 2 - 70, size.height / 2 - 20))

            func point(_ index: Int, _ scale: Double) -> CGPoint {
                let angle = Double(index) * 2 * .pi / Double(metrics.count) - .pi / 2
                return CGPoint(x: center.x + cos(angle) * radius * scale, y: center.y + sin(angle) * radius * scale)
            }

            func polygon(_ scales: [Double]) -> Path {
                Path { path in
                    path.addLines(scales.enumerated().map { point($0.offset, $0.element) })
                    path.closeSubpath()
                }
            }

            for scale in [0.25, 0.5, 0.75, 1.0] {
                context.stroke(polygon(metrics.map { _ in scale }), with: .color(.secondary.opacity(0.25)), lineWidth: 1)
            }
            for (index, metric) in metrics.enumerated() {
                context.stroke(Path { $0.addLines([center, point(index, 1)]) }, with: .color(.secondary.opacity(0.25)), lineWidth: 1)
                let labelPosition = point(index, 1.1)
                let anchor: UnitPoint = index == 0 ? .bottom : index == 3 ? .top : index < 3 ? .leading : .trailing
                context.draw(Text(metric.category.title).font(.caption2), at: labelPosition, anchor: anchor)
            }
            if metrics.contains(where: { $0.fraction != nil }) {
                let scores = polygon(metrics.map { $0.fraction ?? 0 })
                context.fill(scores, with: .color(.blue.opacity(0.16)))
                context.stroke(scores, with: .color(.blue), lineWidth: 2)
            }
        }
        .frame(height: 195)
        .accessibilityHidden(true)
    }
}

private extension View {
    func scorePanel() -> some View {
        frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: .rect(cornerRadius: 18))
    }
}
