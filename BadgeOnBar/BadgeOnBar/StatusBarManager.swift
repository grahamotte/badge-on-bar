import AppKit

@MainActor
final class StatusBarManager {
    private let settings: AppSettings
    private let monitor: BadgeMonitor
    private var statusItems: [String: NSStatusItem] = [:]
    private var statusViews: [String: StatusItemView] = [:]

    var configWindowShower: (() -> Void)?

    init(settings: AppSettings, monitor: BadgeMonitor) {
        self.settings = settings
        self.monitor = monitor

        monitor.onUpdate = { [weak self] in
            self?.updateStatusItems()
        }

        updateStatusItems()
    }

    func updateStatusItems() {
        let monitored = settings.monitoredBundleIDs
        let currentIDs = Set(statusItems.keys)

        for bundleID in currentIDs where !monitored.contains(bundleID) {
            removeStatusItem(for: bundleID)
        }

        for bundleID in monitored {
            let info = lookupAppInfo(for: bundleID)
            let isRunning = monitor.availableApps.contains(where: { $0.bundleID == bundleID })
            let badge = monitor.badges[bundleID] ?? 0

            if let existingView = statusViews[bundleID] {
                existingView.appIcon = info.icon
                existingView.badgeCount = badge
                existingView.isRunning = isRunning
                statusItems[bundleID]?.length = existingView.requiredWidth()
            } else {
                createStatusItem(
                    for: bundleID,
                    icon: info.icon,
                    name: info.name,
                    badge: badge,
                    isRunning: isRunning
                )
            }
        }
    }

    private func createStatusItem(for bundleID: String, icon: NSImage?, name: String, badge: Int, isRunning: Bool) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        let view = StatusItemView(frame: NSRect(x: 0, y: 0, width: 30, height: NSStatusBar.system.thickness))
        view.appIcon = icon
        view.badgeCount = badge
        view.isRunning = isRunning

        view.onLeftClick = { [weak self] in
            self?.openApp(bundleID: bundleID)
        }
        view.onRightClick = { [weak self, weak view] in
            self?.showContextMenu(for: bundleID, name: name, from: view)
        }

        item.view = view
        item.length = view.requiredWidth()

        statusItems[bundleID] = item
        statusViews[bundleID] = view
    }

    private func removeStatusItem(for bundleID: String) {
        if let item = statusItems[bundleID] {
            NSStatusBar.system.removeStatusItem(item)
        }
        statusItems.removeValue(forKey: bundleID)
        statusViews.removeValue(forKey: bundleID)
    }

    private func lookupAppInfo(for bundleID: String) -> (name: String, icon: NSImage?) {
        if let appInfo = monitor.availableApps.first(where: { $0.bundleID == bundleID }) {
            return (appInfo.name, appInfo.icon)
        }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID),
              let bundle = Bundle(url: url) else {
            return (bundleID, nil)
        }
        let name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? bundleID
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        return (name, icon)
    }

    private func showContextMenu(for bundleID: String, name: String, from view: NSView?) {
        let menu = NSMenu()

        let openItem = NSMenuItem(
            title: "Open \(name)",
            action: #selector(openFromMenu(_:)),
            keyEquivalent: ""
        )
        openItem.target = self
        openItem.representedObject = bundleID
        menu.addItem(openItem)

        menu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(
            title: "Settings...",
            action: #selector(showConfigFromMenu),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        let point = view?.convert(NSPoint(x: 0, y: view?.bounds.height ?? 0), to: nil) ?? .zero
        menu.popUp(positioning: nil, at: point, in: view)
    }

    @objc private func openFromMenu(_ sender: NSMenuItem) {
        guard let bundleID = sender.representedObject as? String else { return }
        openApp(bundleID: bundleID)
    }

    @objc private func showConfigFromMenu() {
        configWindowShower?()
    }

    private func openApp(bundleID: String) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return }
        let config = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.openApplication(at: url, configuration: config) { _, _ in }
    }
}
