import SwiftUI

@main
struct PropertyScoreApp: App {
    private let extractor: any ListingExtractor
    private let defaults: UserDefaults

    init() {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-ui-fixture") {
            extractor = FixtureExtractor()
        } else if arguments.contains("-ui-model-unavailable") {
            extractor = UnavailableFixtureExtractor()
        } else if arguments.contains("-ui-model-failure") {
            extractor = FailingFixtureExtractor()
        } else {
            extractor = OnDeviceExtractor()
        }
        if let index = arguments.firstIndex(of: "-ui-defaults-suite"), arguments.indices.contains(index + 1),
           let suite = UserDefaults(suiteName: arguments[index + 1]) {
            defaults = suite
        } else {
            defaults = .standard
        }
        #else
        extractor = OnDeviceExtractor()
        defaults = .standard
        #endif
    }

    var body: some Scene {
        WindowGroup {
            AnalysisView(extractor: extractor, defaults: defaults)
                .tint(.blue)
        }
    }
}
