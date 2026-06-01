import Foundation
import Observation
import OSLog

private let settingsLog = Logger(subsystem: "com.grahamotte.badgeonbar", category: "AppSettings")

@MainActor
@Observable
final class AppSettings {
    var monitoredBundleIDs: Set<String> = []

    var onChanged: (() -> Void)?

    private let defaults = UserDefaults.standard
    private let key = "monitoredBundleIDs"

    init() {
        if let ids = defaults.stringArray(forKey: key) {
            monitoredBundleIDs = Set(ids)
        }
        settingsLog.info("loaded \(self.monitoredBundleIDs.count) monitored apps")
    }

    func setMonitored(_ bundleID: String, monitored: Bool) {
        let wasMonitored = monitoredBundleIDs.contains(bundleID)
        if monitored {
            monitoredBundleIDs.insert(bundleID)
        } else {
            monitoredBundleIDs.remove(bundleID)
        }
        settingsLog.info("setMonitored \(bundleID, privacy: .public) = \(monitored) (was \(wasMonitored), now \(self.monitoredBundleIDs.count) total)")
        save()
        onChanged?()
    }

    func toggle(_ bundleID: String) {
        setMonitored(bundleID, monitored: !monitoredBundleIDs.contains(bundleID))
    }

    func isMonitored(_ bundleID: String) -> Bool {
        monitoredBundleIDs.contains(bundleID)
    }

    private func save() {
        defaults.set(Array(monitoredBundleIDs), forKey: key)
    }
}
