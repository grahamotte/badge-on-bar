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

@MainActor
@Observable
final class AppSettings {
    var monitoredBundleIDs: Set<String> = []
    var startAtLogin = false
    var demoBadgeOverride: Int?
    var dotBadgeDefault = false
    var dotBadgeOverrides: [String: Bool] = [:]
    var badgeColorDefault: BadgeColorOption = .red
    var badgeColorOverrides: [String: BadgeColorOption] = [:]
    var zeroBehaviorDefault: ZeroBehavior = .show
    var zeroBehaviorOverrides: [String: ZeroBehavior] = [:]
    var symbolOverrides: [String: String] = [:]

    @ObservationIgnored private var demoTask: Task<Void, Never>?
    var onChanged: (() -> Void)?

    private let defaults = UserDefaults.standard
    private let monitoredKey = "monitoredBundleIDs"
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
        dotBadgeDefault = defaults.bool(forKey: dotBadgeDefaultKey)
        if let overrides = defaults.dictionary(forKey: dotBadgeOverridesKey) as? [String: Bool] {
            dotBadgeOverrides = overrides
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
                dotBadgeOverrides[id] = true
            }
            defaults.removeObject(forKey: "dotBadgeBundleIDs")
            persistDotBadge()
        }

        for bundleID in monitoredBundleIDs where dotBadgeOverrides[bundleID] == nil {
            dotBadgeOverrides[bundleID] = dotBadgeDefault
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
            dotBadgeOverrides[bundleID] = dotBadgeDefault
            badgeColorOverrides[bundleID] = badgeColorDefault
            zeroBehaviorOverrides[bundleID] = zeroBehaviorDefault
        } else {
            monitoredBundleIDs.remove(bundleID)
            dotBadgeOverrides.removeValue(forKey: bundleID)
            badgeColorOverrides.removeValue(forKey: bundleID)
            zeroBehaviorOverrides.removeValue(forKey: bundleID)
            symbolOverrides.removeValue(forKey: bundleID)
        }
        save()
        persistDotBadge()
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
        dotBadgeDefault = false
        dotBadgeOverrides = [:]
        badgeColorDefault = .red
        badgeColorOverrides = [:]
        zeroBehaviorDefault = .show
        zeroBehaviorOverrides = [:]
        symbolOverrides = [:]
        setStartAtLogin(false)
        [
            monitoredKey, dotBadgeOverridesKey, dotBadgeDefaultKey,
            badgeColorDefaultKey, badgeColorOverridesKey,
            zeroBehaviorDefaultKey, zeroBehaviorOverridesKey,
            symbolOverridesKey, "dotBadgeBundleIDs"
        ].forEach(defaults.removeObject(forKey:))
        onChanged?()
    }

    func isDotBadge(_ bundleID: String) -> Bool {
        dotBadgeOverrides[bundleID] ?? dotBadgeDefault
    }

    func setDotBadge(_ bundleID: String, enabled: Bool) {
        dotBadgeOverrides[bundleID] = enabled
        persistDotBadge()
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

    func setDotBadgeDefault(_ enabled: Bool) {
        dotBadgeDefault = enabled
        defaults.set(dotBadgeDefault, forKey: dotBadgeDefaultKey)
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

    func setAllDotBadgesToDefault() {
        let monitored = monitoredBundleIDs
        for bundleID in monitored {
            dotBadgeOverrides[bundleID] = dotBadgeDefault
        }
        persistDotBadge()
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

    var allDotBadgesMatchDefault: Bool {
        for bundleID in monitoredBundleIDs {
            if dotBadgeOverrides[bundleID] != dotBadgeDefault {
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

    private func persistDotBadge() {
        defaults.set(dotBadgeOverrides, forKey: dotBadgeOverridesKey)
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
