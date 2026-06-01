import Foundation
import Observation

@MainActor
@Observable
final class AppSettings {
    var monitoredBundleIDs: Set<String> = []

    private let defaults = UserDefaults.standard
    private let key = "monitoredBundleIDs"

    init() {
        if let ids = defaults.stringArray(forKey: key) {
            monitoredBundleIDs = Set(ids)
        }
    }

    func toggle(_ bundleID: String) {
        if monitoredBundleIDs.contains(bundleID) {
            monitoredBundleIDs.remove(bundleID)
        } else {
            monitoredBundleIDs.insert(bundleID)
        }
        save()
    }

    func isMonitored(_ bundleID: String) -> Bool {
        monitoredBundleIDs.contains(bundleID)
    }

    private func save() {
        defaults.set(Array(monitoredBundleIDs), forKey: key)
    }
}
