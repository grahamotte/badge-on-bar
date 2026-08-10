import XCTest
@testable import BadgeOnBarCore

@MainActor
final class AppSettingsTests: XCTestCase {
    func testMonitoringSeedsPersistsAndRemovesOverrides() {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = AppSettings(defaults: defaults)
        var changeCount = 0
        settings.onChanged = { changeCount += 1 }

        settings.setDisplayModeDefault(.count)
        settings.setBadgeColorDefault(.purple)
        settings.setZeroBehaviorDefault(.hide)
        settings.setMonitored("com.example.app", monitored: true)

        XCTAssertTrue(settings.isMonitored("com.example.app"))
        XCTAssertEqual(settings.displayMode(for: "com.example.app"), .count)
        XCTAssertEqual(settings.badgeColor(for: "com.example.app"), .purple)
        XCTAssertEqual(settings.zeroBehavior(for: "com.example.app"), .hide)
        XCTAssertEqual(changeCount, 4)

        let restored = AppSettings(defaults: defaults)
        XCTAssertTrue(restored.isMonitored("com.example.app"))
        XCTAssertEqual(restored.displayMode(for: "com.example.app"), .count)
        XCTAssertEqual(restored.badgeColor(for: "com.example.app"), .purple)
        XCTAssertEqual(restored.zeroBehavior(for: "com.example.app"), .hide)

        settings.setSymbolOverride("com.example.app", symbolName: "envelope")
        settings.setMonitored("com.example.app", monitored: false)

        XCTAssertFalse(settings.isMonitored("com.example.app"))
        XCTAssertNil(settings.displayModeOverrides["com.example.app"])
        XCTAssertNil(settings.badgeColorOverrides["com.example.app"])
        XCTAssertNil(settings.zeroBehaviorOverrides["com.example.app"])
        XCTAssertNil(settings.symbolOverride(for: "com.example.app"))
    }

    func testPerAppSettingsAndBulkResetUseCurrentDefaults() {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = AppSettings(defaults: defaults)
        settings.setMonitored("com.example.first", monitored: true)
        settings.setMonitored("com.example.second", monitored: true)
        settings.setDisplayMode("com.example.first", mode: .question)
        settings.setBadgeColor("com.example.first", color: .pink)
        settings.setZeroBehavior("com.example.first", behavior: .greyscale)

        XCTAssertFalse(settings.allDisplayModesMatchDefault)
        XCTAssertFalse(settings.allBadgeColorsMatchDefault)
        XCTAssertFalse(settings.allZeroBehaviorsMatchDefault)

        settings.setDisplayModeDefault(.dot)
        settings.setBadgeColorDefault(.blue)
        settings.setZeroBehaviorDefault(.hide)
        settings.setAllDisplayModesToDefault()
        settings.setAllBadgeColorsToDefault()
        settings.setAllZeroBehaviorsToDefault()

        XCTAssertTrue(settings.allDisplayModesMatchDefault)
        XCTAssertTrue(settings.allBadgeColorsMatchDefault)
        XCTAssertTrue(settings.allZeroBehaviorsMatchDefault)
        XCTAssertEqual(settings.displayMode(for: "com.example.first"), .dot)
        XCTAssertEqual(settings.badgeColor(for: "com.example.first"), .blue)
        XCTAssertEqual(settings.zeroBehavior(for: "com.example.first"), .hide)
    }

    func testLegacyDotSettingsMigrateToDisplayModes() {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: "dotBadgeDefault")
        defaults.set(["com.example.first": false, "com.example.second": true], forKey: "dotBadgeOverrides")
        defaults.set(["com.example.legacy"], forKey: "dotBadgeBundleIDs")

        let settings = AppSettings(defaults: defaults)

        XCTAssertEqual(settings.displayModeDefault, .dot)
        XCTAssertEqual(settings.displayMode(for: "com.example.first"), .badge)
        XCTAssertEqual(settings.displayMode(for: "com.example.second"), .dot)
        XCTAssertEqual(settings.displayMode(for: "com.example.legacy"), .dot)
        XCTAssertNil(defaults.object(forKey: "dotBadgeBundleIDs"))
    }

    func testOptionLabelsAndIdentifiersMatchPersistedValues() {
        XCTAssertEqual(BadgeColorOption.allCases.map(\.id), ["red", "green", "blue", "purple", "black", "pink"])
        XCTAssertEqual(ZeroBehavior.allCases.map(\.name), ["Show", "Greyscale", "Hide"])
        XCTAssertEqual(DisplayMode.allCases.map(\.name), ["Badge", "Dot", "Count", "Question"])
    }

    private func makeDefaults() -> (UserDefaults, String) {
        let suite = "BadgeOnBarTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return (defaults, suite)
    }
}
