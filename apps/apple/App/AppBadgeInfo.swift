import AppKit

struct AppBadgeInfo: Identifiable, Equatable {
    let bundleID: String
    let name: String
    let icon: NSImage?

    var id: String { bundleID }

    static func fromBundleID(_ bundleID: String, fallbackName: String? = nil) -> AppBadgeInfo? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID),
              let bundle = Bundle(url: url) else { return nil }

        let name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? fallbackName
            ?? bundleID
        return AppBadgeInfo(bundleID: bundleID, name: name, icon: NSWorkspace.shared.icon(forFile: url.path))
    }

    static func == (lhs: AppBadgeInfo, rhs: AppBadgeInfo) -> Bool {
        lhs.bundleID == rhs.bundleID
    }
}
