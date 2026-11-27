import SwiftUI

private enum InputMode: String, CaseIterable, Identifiable {
    case url = "物件URL"
    case paste = "掲載文"
    var id: Self { self }
}

struct AnalysisView: View {
    let extractor: any ListingExtractor
    let defaults: UserDefaults

    @Environment(\.scenePhase) private var scenePhase
    @State private var path = NavigationPath()
    @State private var conditions: Conditions
    @State private var mode = InputMode.url
    @State private var url = ""
    @State private var text = ""
    @State private var error: String?
    @State private var busy = false
    @State private var unavailableReason: String?
    @FocusState private var inputFocused: Bool

    init(extractor: any ListingExtractor, defaults: UserDefaults) {
        self.extractor = extractor
        self.defaults = defaults
        _conditions = State(initialValue: defaults.data(forKey: "conditions")
            .flatMap { try? JSONDecoder().decode(Conditions.self, from: $0) } ?? Conditions())
        _unavailableReason = State(initialValue: extractor.unavailableReason)
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("不動産投資の一次評価", systemImage: "chart.bar.xaxis")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.blue)
                        Text("物件を、自分の\n条件で見極める。")
                            .font(.system(.largeTitle, design: .default, weight: .bold))
                            .accessibilityAddTraits(.isHeader)
                        Text("掲載情報をもとに、6つの観点で物件を比較できます。")
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("物件情報").font(.headline).accessibilityAddTraits(.isHeader)
                        Picker("入力方法", selection: $mode) {
                            ForEach(InputMode.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)

                        switch mode {
                        case .url:
                            TextField("https://…", text: $url)
                                .textContentType(.URL)
                                .keyboardType(.URL)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .padding(12)
                                .background(.background, in: .rect(cornerRadius: 10))
                                .accessibilityLabel("物件URL")
                                .accessibilityIdentifier("listing-url")
                                .focused($inputFocused)
                        case .paste:
                            ZStack(alignment: .topLeading) {
                                if text.isEmpty {
                                    Text("掲載ページの物件情報を貼り付け")
                                        .foregroundStyle(.secondary)
                                        .padding(8)
                                        .allowsHitTesting(false)
                                }
                                TextEditor(text: $text)
                                    .scrollContentBackground(.hidden)
                                    .frame(minHeight: 115)
                                    .padding(4)
                                    .focused($inputFocused)
                                    .accessibilityLabel("掲載文")
                                    .accessibilityIdentifier("listing-text")
                            }
                            .background(.background, in: .rect(cornerRadius: 10))
                        }

                        if let unavailableReason {
                            Label(unavailableReason + " 手入力で分析できます。", systemImage: "info.circle")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .accessibilityIdentifier("model-status")
                        }
                        if let error {
                            Label(error, systemImage: "exclamationmark.circle")
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .accessibilityIdentifier("listing-error")
                        }
                        Button {
                            inputFocused = false
                            Task { await extract() }
                        } label: {
                            HStack {
                                if busy { ProgressView().tint(.white) }
                                else { Image(systemName: "sparkles") }
                                Text(busy ? "読み取り中…" : "掲載情報を読み取る")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .accessibilityIdentifier("extract-listing")
                        .disabled(busy || unavailableReason != nil || (mode == .url ? url : text)
                            .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                        Button {
                            inputFocused = false
                            path.append(Destination.fields(Listing()))
                        } label: {
                            Text("手入力で分析する").frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .accessibilityIdentifier("manual-listing")
                        .disabled(busy)
                    }
                    .padding(16)
                    .background(Color(uiColor: .secondarySystemGroupedBackground), in: .rect(cornerRadius: 18))

                    Label("AIは掲載文から項目を抽出するだけです。採点は設定した条件と計算式で行います。", systemImage: "lock.shield")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("PropertyScore")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        path.append(Destination.conditions)
                    } label: {
                        Label("分析条件", systemImage: "slider.horizontal.3")
                    }
                    .accessibilityIdentifier("open-conditions")
                    .disabled(busy)
                }
                ToolbarItem(placement: .keyboard) {
                    Button("完了") { inputFocused = false }
                }
            }
            .navigationDestination(for: Destination.self) { destination in
                switch destination {
                case .fields(let listing):
                    ListingEditor(initial: listing) { path.append(Destination.result($0)) }
                case .result(let listing):
                    ResultView(listing: listing, score: Scoring.evaluate(listing, conditions))
                case .conditions:
                    ConditionsView(initial: conditions) { updated in
                        conditions = updated
                        if let data = try? JSONEncoder().encode(updated) {
                            defaults.set(data, forKey: "conditions")
                        }
                        path.removeLast()
                    }
                }
            }
        }
        .onChange(of: scenePhase) {
            if scenePhase == .active { unavailableReason = extractor.unavailableReason }
        }
    }

    private func extract() async {
        guard !busy else { return }
        busy = true
        error = nil
        defer { busy = false }

        let source: String
        do {
            switch mode {
            case .url: source = try await ListingPage.load(url)
            case .paste: source = text
            }
        } catch {
            self.error = (error as? ListingPage.Failure)?.errorDescription ?? ListingPage.Failure.unavailable.localizedDescription
            return
        }

        do {
            let listing = try await extractor.extract(source)
            path.append(Destination.fields(listing))
        } catch {
            unavailableReason = extractor.unavailableReason
            self.error = "読み取りに失敗しました。掲載文を短くするか、手入力で分析してください。"
        }
    }

    private enum Destination: Hashable {
        case fields(Listing), result(Listing), conditions
    }
}
