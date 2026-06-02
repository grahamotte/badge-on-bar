import Foundation
import Observation

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

    private func save() {
        defaults.set(Array(monitoredBundleIDs), forKey: key)
    }
}
