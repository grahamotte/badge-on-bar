import Foundation
import Observation
import ServiceManagement

enum BadgeColorOption: String, CaseIterable, Identifiable {
    case red, green, blue, purple, black, pink

    var id: String { rawValue }
    var name: String { rawValue.capitalized }
}

enum ZeroBehavior: String, CaseIterable, Identifiable {
    case show, greyscale, hide

    var id: String { rawValue }
    var name: String { rawValue.capitalized }
}

enum DisplayMode: String, CaseIterable, Identifiable {
    case badge, dot, question

    var id: String { rawValue }
    var name: String { rawValue.capitalized }
}

@MainActor
@Observable
final class AppSettings {
    var monitoredBundleIDs: Set<String> = []
    var startAtLogin = false
    var demoBadgeOverride: Int?
    var displayModeDefault: DisplayMode = .badge
    var displayModeOverrides: [String: DisplayMode] = [:]
    var badgeColorDefault: BadgeColorOption = .red
    var badgeColorOverrides: [String: BadgeColorOption] = [:]
    var zeroBehaviorDefault: ZeroBehavior = .show
    var zeroBehaviorOverrides: [String: ZeroBehavior] = [:]
    var symbolOverrides: [String: String] = [:]

    @ObservationIgnored private var demoTask: Task<Void, Never>?
    var onChanged: (() -> Void)?

    private let defaults = UserDefaults.standard
    private let monitoredKey = "monitoredBundleIDs"
    private let displayModeDefaultKey = "displayModeDefault"
    private let displayModeOverridesKey = "displayModeOverrides"
    private let dotBadgeOverridesKey = "dotBadgeOverrides"
    private let dotBadgeDefaultKey = "dotBadgeDefault"
    private let badgeColorDefaultKey = "badgeColorDefault"
    private let badgeColorOverridesKey = "badgeColorOverrides"
    private let zeroBehaviorDefaultKey = "zeroBehaviorDefault"
    private let zeroBehaviorOverridesKey = "zeroBehaviorOverrides"
    private let symbolOverridesKey = "symbolOverrides"

    init() {
        if let ids = defaults.stringArray(forKey: monitoredKey) {
            monitoredBundleIDs = Set(ids)
        }
        refreshStartAtLoginStatus()
        if let rawDefault = defaults.string(forKey: displayModeDefaultKey),
           let mode = DisplayMode(rawValue: rawDefault) {
            displayModeDefault = mode
        } else if defaults.object(forKey: dotBadgeDefaultKey) != nil {
            displayModeDefault = defaults.bool(forKey: dotBadgeDefaultKey) ? .dot : .badge
        }
        if let overrides = defaults.dictionary(forKey: displayModeOverridesKey) as? [String: String] {
            displayModeOverrides = overrides.compactMapValues(DisplayMode.init(rawValue:))
        } else if let overrides = defaults.dictionary(forKey: dotBadgeOverridesKey) as? [String: Bool] {
            displayModeOverrides = overrides.mapValues { $0 ? .dot : .badge }
        }
        if let rawDefault = defaults.string(forKey: badgeColorDefaultKey),
           let color = BadgeColorOption(rawValue: rawDefault) {
            badgeColorDefault = color
        }
        if let overrides = defaults.dictionary(forKey: badgeColorOverridesKey) as? [String: String] {
            badgeColorOverrides = overrides.compactMapValues(BadgeColorOption.init(rawValue:))
        }
        if let rawDefault = defaults.string(forKey: zeroBehaviorDefaultKey),
           let behavior = ZeroBehavior(rawValue: rawDefault) {
            zeroBehaviorDefault = behavior
        }
        if let overrides = defaults.dictionary(forKey: zeroBehaviorOverridesKey) as? [String: String] {
            zeroBehaviorOverrides = overrides.compactMapValues(ZeroBehavior.init(rawValue:))
        }
        if let overrides = defaults.dictionary(forKey: symbolOverridesKey) as? [String: String] {
            symbolOverrides = overrides
        }
        if let ids = defaults.stringArray(forKey: "dotBadgeBundleIDs") {
            for id in ids {
                displayModeOverrides[id] = .dot
            }
            defaults.removeObject(forKey: "dotBadgeBundleIDs")
            persistDisplayModes()
        }

        for bundleID in monitoredBundleIDs where displayModeOverrides[bundleID] == nil {
            displayModeOverrides[bundleID] = displayModeDefault
        }
        for bundleID in monitoredBundleIDs where badgeColorOverrides[bundleID] == nil {
            badgeColorOverrides[bundleID] = badgeColorDefault
        }
        for bundleID in monitoredBundleIDs where zeroBehaviorOverrides[bundleID] == nil {
            zeroBehaviorOverrides[bundleID] = zeroBehaviorDefault
        }
    }

    func setMonitored(_ bundleID: String, monitored: Bool) {
        if monitored {
            monitoredBundleIDs.insert(bundleID)
            displayModeOverrides[bundleID] = displayModeDefault
            badgeColorOverrides[bundleID] = badgeColorDefault
            zeroBehaviorOverrides[bundleID] = zeroBehaviorDefault
        } else {
            monitoredBundleIDs.remove(bundleID)
            displayModeOverrides.removeValue(forKey: bundleID)
            badgeColorOverrides.removeValue(forKey: bundleID)
            zeroBehaviorOverrides.removeValue(forKey: bundleID)
            symbolOverrides.removeValue(forKey: bundleID)
        }
        save()
        persistDisplayModes()
        persistBadgeColors()
        persistZeroBehavior()
        persistSymbols()
        onChanged?()
    }

    func toggle(_ bundleID: String) {
        setMonitored(bundleID, monitored: !monitoredBundleIDs.contains(bundleID))
    }

    func isMonitored(_ bundleID: String) -> Bool {
        monitoredBundleIDs.contains(bundleID)
    }

    func setStartAtLogin(_ enabled: Bool) {
        startAtLogin = enabled
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            refreshStartAtLoginStatus()
        }
    }

    func refreshStartAtLoginStatus() {
        startAtLogin = SMAppService.mainApp.status == .enabled
    }

    func showBadgeDemo(_ count: Int) {
        demoTask?.cancel()
        demoBadgeOverride = count
        onChanged?()
        demoTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.demoBadgeOverride = nil
                self?.onChanged?()
            }
        }
    }

    func resetAllToDefaults() {
        demoTask?.cancel()
        demoBadgeOverride = nil
        monitoredBundleIDs = []
        displayModeDefault = .badge
        displayModeOverrides = [:]
        badgeColorDefault = .red
        badgeColorOverrides = [:]
        zeroBehaviorDefault = .show
        zeroBehaviorOverrides = [:]
        symbolOverrides = [:]
        setStartAtLogin(false)
        [
            monitoredKey, displayModeDefaultKey, displayModeOverridesKey,
            dotBadgeOverridesKey, dotBadgeDefaultKey,
            badgeColorDefaultKey, badgeColorOverridesKey,
            zeroBehaviorDefaultKey, zeroBehaviorOverridesKey,
            symbolOverridesKey, "dotBadgeBundleIDs"
        ].forEach(defaults.removeObject(forKey:))
        onChanged?()
    }

    func displayMode(for bundleID: String) -> DisplayMode {
        displayModeOverrides[bundleID] ?? displayModeDefault
    }

    func setDisplayMode(_ bundleID: String, mode: DisplayMode) {
        displayModeOverrides[bundleID] = mode
        persistDisplayModes()
        onChanged?()
    }

    func badgeColor(for bundleID: String) -> BadgeColorOption {
        badgeColorOverrides[bundleID] ?? badgeColorDefault
    }

    func setBadgeColor(_ bundleID: String, color: BadgeColorOption) {
        badgeColorOverrides[bundleID] = color
        persistBadgeColors()
        onChanged?()
    }

    func zeroBehavior(for bundleID: String) -> ZeroBehavior {
        zeroBehaviorOverrides[bundleID] ?? zeroBehaviorDefault
    }

    func setZeroBehavior(_ bundleID: String, behavior: ZeroBehavior) {
        zeroBehaviorOverrides[bundleID] = behavior
        persistZeroBehavior()
        onChanged?()
    }

    func symbolOverride(for bundleID: String) -> String? {
        symbolOverrides[bundleID]
    }

    func setSymbolOverride(_ bundleID: String, symbolName: String?) {
        symbolOverrides[bundleID] = symbolName
        persistSymbols()
        onChanged?()
    }

    func setDisplayModeDefault(_ mode: DisplayMode) {
        displayModeDefault = mode
        defaults.set(mode.rawValue, forKey: displayModeDefaultKey)
        onChanged?()
    }

    func setBadgeColorDefault(_ color: BadgeColorOption) {
        badgeColorDefault = color
        defaults.set(color.rawValue, forKey: badgeColorDefaultKey)
        onChanged?()
    }

    func setZeroBehaviorDefault(_ behavior: ZeroBehavior) {
        zeroBehaviorDefault = behavior
        defaults.set(behavior.rawValue, forKey: zeroBehaviorDefaultKey)
        onChanged?()
    }

    func setAllDisplayModesToDefault() {
        let monitored = monitoredBundleIDs
        for bundleID in monitored {
            displayModeOverrides[bundleID] = displayModeDefault
        }
        persistDisplayModes()
        onChanged?()
    }

    func setAllBadgeColorsToDefault() {
        for bundleID in monitoredBundleIDs {
            badgeColorOverrides[bundleID] = badgeColorDefault
        }
        persistBadgeColors()
        onChanged?()
    }

    func setAllZeroBehaviorsToDefault() {
        for bundleID in monitoredBundleIDs {
            zeroBehaviorOverrides[bundleID] = zeroBehaviorDefault
        }
        persistZeroBehavior()
        onChanged?()
    }

    var allDisplayModesMatchDefault: Bool {
        for bundleID in monitoredBundleIDs {
            if displayModeOverrides[bundleID] != displayModeDefault {
                return false
            }
        }
        return true
    }

    var allBadgeColorsMatchDefault: Bool {
        for bundleID in monitoredBundleIDs {
            if badgeColorOverrides[bundleID] != badgeColorDefault {
                return false
            }
        }
        return true
    }

    var allZeroBehaviorsMatchDefault: Bool {
        for bundleID in monitoredBundleIDs {
            if zeroBehaviorOverrides[bundleID] != zeroBehaviorDefault {
                return false
            }
        }
        return true
    }

    private func persistDisplayModes() {
        defaults.set(displayModeOverrides.mapValues(\.rawValue), forKey: displayModeOverridesKey)
    }

    private func persistBadgeColors() {
        defaults.set(badgeColorOverrides.mapValues(\.rawValue), forKey: badgeColorOverridesKey)
    }

    private func persistZeroBehavior() {
        defaults.set(zeroBehaviorOverrides.mapValues(\.rawValue), forKey: zeroBehaviorOverridesKey)
    }

    private func persistSymbols() {
        defaults.set(symbolOverrides, forKey: symbolOverridesKey)
    }

    private func save() {
        defaults.set(Array(monitoredBundleIDs), forKey: monitoredKey)
    }
}
