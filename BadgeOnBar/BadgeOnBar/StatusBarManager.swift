import AppKit

@MainActor
final class StatusBarManager {
    private let settings: AppSettings
    private let monitor: BadgeMonitor
    private var items: [String: NSStatusItem] = [:]

    init(settings: AppSettings, monitor: BadgeMonitor) {
        self.settings = settings
        self.monitor = monitor
        monitor.onUpdate = { [weak self] in self?.sync() }
        settings.onChanged = { [weak self] in self?.sync() }
        sync()
    }

    func sync() {
        let monitored = settings.monitoredBundleIDs

        for id in items.keys where !monitored.contains(id) {
            NSStatusBar.system.removeStatusItem(items[id]!)
            items[id] = nil
        }

        for bundleID in monitored {
            let running = monitor.availableApps.contains { $0.bundleID == bundleID }
            let badge = monitor.badges[bundleID] ?? 0
            let appInfo = monitor.availableApps.first { $0.bundleID == bundleID }
            let (name, icon) = resolve(bundleID, runningApp: appInfo)

            if let item = items[bundleID] {
                let btn = item.button!
                btn.image = resizedIcon(icon, to: 18)
                btn.image?.isTemplate = false
                btn.imagePosition = .imageLeading
                btn.alphaValue = running ? 1 : 0.35
                let attr = badgeString(badge)
                btn.attributedTitle = attr
                btn.title = attr.string
                let textWidth = max(0, (attr.string as NSString).size(withAttributes: [.font: NSFont.boldSystemFont(ofSize: NSFont.smallSystemFontSize)]).width)
                item.length = badge == 0 ? max(18, ceil(textWidth)) : 20 + ceil(textWidth)
                btn.toolTip = name
            } else {
                let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
                item.autosaveName = "BadgeOnBar_\(bundleID)"
                let btn = item.button!
                btn.image = resizedIcon(icon, to: 18)
                btn.imagePosition = .imageLeading
                btn.alphaValue = running ? 1 : 0.35
                let attr = badgeString(badge)
                btn.attributedTitle = attr
                btn.title = attr.string
                let textWidth = max(0, (attr.string as NSString).size(withAttributes: [.font: NSFont.boldSystemFont(ofSize: NSFont.smallSystemFontSize)]).width)
                item.length = badge == 0 ? max(18, ceil(textWidth)) : 20 + ceil(textWidth)
                btn.toolTip = name
                btn.target = self
                btn.action = #selector(clicked(_:))
                btn.sendAction(on: .leftMouseUp)

                items[bundleID] = item
            }
        }
    }

    @objc private func clicked(_ sender: NSStatusBarButton) {
        guard let (id, _) = items.first(where: { $0.value.button == sender }) else { return }
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()) { _, _ in }
        }
    }

    private func resizedIcon(_ icon: NSImage?, to size: CGFloat) -> NSImage? {
        guard let icon else { return nil }
        let s = NSSize(width: size, height: size)
        let image = NSImage(size: s, flipped: false) { _ in
            icon.draw(in: NSRect(origin: .zero, size: s))
            return true
        }
        image.isTemplate = false
        return image
    }

    private func badgeString(_ count: Int) -> NSAttributedString {
        guard count > 0 else { return NSAttributedString() }
        let text = count > 99 ? "99+" : "\(count)"
        return NSAttributedString(string: text, attributes: [
            .font: NSFont.boldSystemFont(ofSize: NSFont.smallSystemFontSize),
            .foregroundColor: NSColor.systemRed
        ])
    }

    private func resolve(_ bundleID: String, runningApp: AppBadgeInfo?) -> (String, NSImage?) {
        if let runningApp, runningApp.icon != nil { return (runningApp.name, runningApp.icon) }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID),
              let bundle = Bundle(url: url) else { return (bundleID, nil) }
        let name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String) ?? bundleID
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        return (name, icon)
    }
}

