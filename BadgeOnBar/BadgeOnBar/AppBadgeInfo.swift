import AppKit

struct AppBadgeInfo: Identifiable, Equatable {
    let bundleID: String
    let name: String
    let icon: NSImage?

    var id: String { bundleID }

    static func == (lhs: AppBadgeInfo, rhs: AppBadgeInfo) -> Bool {
        lhs.bundleID == rhs.bundleID
    }
}
