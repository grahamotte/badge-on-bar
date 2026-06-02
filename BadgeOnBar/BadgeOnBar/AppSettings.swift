import Foundation
import Observation
import ServiceManagement

@MainActor
@Observable
final class AppSettings {
    var monitoredBundleIDs: Set<String> = []
    var startAtLogin = false
    var demoModeEnabled = false
    var demoBadgeCount = 1

    var onChanged: (() -> Void)?

    private let defaults = UserDefaults.standard
    private let monitoredKey = "monitoredBundleIDs"
    private let startAtLoginKey = "startAtLogin"
    private let demoModeKey = "demoModeEnabled"
    private let demoCountKey = "demoBadgeCount"

    init() {
        if let ids = defaults.stringArray(forKey: monitoredKey) {
            monitoredBundleIDs = Set(ids)
        }
        startAtLogin = defaults.bool(forKey: startAtLoginKey)
        demoModeEnabled = defaults.bool(forKey: demoModeKey)
        if defaults.object(forKey: demoCountKey) != nil {
            demoBadgeCount = max(0, defaults.integer(forKey: demoCountKey))
        }
    }

    func setMonitored(_ bundleID: String, monitored: Bool) {
        if monitored {
            monitoredBundleIDs.insert(bundleID)
        } else {
            monitoredBundleIDs.remove(bundleID)
        }
        save()
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
        defaults.set(enabled, forKey: startAtLoginKey)
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            startAtLogin = false
            defaults.set(false, forKey: startAtLoginKey)
        }
    }

    func refreshStartAtLoginStatus() {
        startAtLogin = SMAppService.mainApp.status == .enabled
        defaults.set(startAtLogin, forKey: startAtLoginKey)
    }

    func setDemoMode(_ enabled: Bool) {
        demoModeEnabled = enabled
        defaults.set(enabled, forKey: demoModeKey)
        onChanged?()
    }

    func setDemoBadgeCount(_ count: Int) {
        demoBadgeCount = max(0, count)
        defaults.set(demoBadgeCount, forKey: demoCountKey)
        onChanged?()
    }

    private func save() {
        defaults.set(Array(monitoredBundleIDs), forKey: monitoredKey)
    }
}
