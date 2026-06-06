import Foundation
import Observation
import ServiceManagement

@MainActor
@Observable
final class AppSettings {
    var monitoredBundleIDs: Set<String> = []
    var startAtLogin = false
    var demoBadgeOverride: Int?
    var dotBadgeDefault = false
    var dotBadgeOverrides: [String: Bool] = [:]
    var symbolOverrides: [String: String] = [:]

    @ObservationIgnored private var demoTask: Task<Void, Never>?
    var onChanged: (() -> Void)?

    private let defaults = UserDefaults.standard
    private let monitoredKey = "monitoredBundleIDs"
    private let dotBadgeOverridesKey = "dotBadgeOverrides"
    private let dotBadgeDefaultKey = "dotBadgeDefault"
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
    }

    func setMonitored(_ bundleID: String, monitored: Bool) {
        if monitored {
            monitoredBundleIDs.insert(bundleID)
            dotBadgeOverrides[bundleID] = dotBadgeDefault
        } else {
            monitoredBundleIDs.remove(bundleID)
            dotBadgeOverrides.removeValue(forKey: bundleID)
            symbolOverrides.removeValue(forKey: bundleID)
        }
        save()
        persistDotBadge()
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

    func isDotBadge(_ bundleID: String) -> Bool {
        dotBadgeOverrides[bundleID] ?? dotBadgeDefault
    }

    func setDotBadge(_ bundleID: String, enabled: Bool) {
        dotBadgeOverrides[bundleID] = enabled
        persistDotBadge()
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

    func setAllDotBadgesToDefault() {
        let monitored = monitoredBundleIDs
        for bundleID in monitored {
            dotBadgeOverrides[bundleID] = dotBadgeDefault
        }
        persistDotBadge()
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

    private func persistDotBadge() {
        defaults.set(dotBadgeOverrides, forKey: dotBadgeOverridesKey)
    }

    private func persistSymbols() {
        defaults.set(symbolOverrides, forKey: symbolOverridesKey)
    }

    private func save() {
        defaults.set(Array(monitoredBundleIDs), forKey: monitoredKey)
    }
}
