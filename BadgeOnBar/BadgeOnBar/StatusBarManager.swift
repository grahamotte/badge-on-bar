import AppKit

@MainActor
final class StatusBarManager {
    private let settings: AppSettings
    private let monitor: BadgeMonitor
    private var statusItems: [String: NSStatusItem] = [:]

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
        let currentItems = Set(statusItems.keys)

        for bundleID in currentItems {
            let isRunning = monitor.availableApps.contains(where: { $0.bundleID == bundleID })
            if !monitored.contains(bundleID) || !isRunning {
                if let item = statusItems[bundleID] {
                    NSStatusBar.system.removeStatusItem(item)
                    statusItems.removeValue(forKey: bundleID)
                }
            }
        }

        for appInfo in monitor.availableApps where monitored.contains(appInfo.bundleID) {
            let badge = monitor.badges[appInfo.bundleID] ?? 0
            if let existingItem = statusItems[appInfo.bundleID] {
                updateStatusItem(existingItem, appInfo: appInfo, badge: badge)
            } else {
                let item = createStatusItem(for: appInfo, badge: badge)
                statusItems[appInfo.bundleID] = item
            }
        }
    }

    private func createStatusItem(for appInfo: AppBadgeInfo, badge: Int) -> NSStatusItem {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = item.button {
            button.image = compositeIcon(icon: appInfo.icon, badge: badge)
            button.imagePosition = .imageOnly
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.toolTip = appInfo.name
            button.sendAction(on: .leftMouseUp)
        }

        let menu = NSMenu()
        let openItem = NSMenuItem(
            title: "Open \(appInfo.name)",
            action: #selector(openAppFromMenu(_:)),
            keyEquivalent: ""
        )
        openItem.target = self
        openItem.representedObject = appInfo.bundleID
        menu.addItem(openItem)

        menu.addItem(NSMenuItem.separator())
        let settingsItem = NSMenuItem(
            title: "Settings...",
            action: #selector(showConfigFromMenu),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        item.menu = menu

        return item
    }

    @objc private func openAppFromMenu(_ sender: NSMenuItem) {
        guard let bundleID = sender.representedObject as? String else { return }
        openApp(bundleID: bundleID)
    }

    private func updateStatusItem(_ item: NSStatusItem, appInfo: AppBadgeInfo, badge: Int) {
        item.button?.image = compositeIcon(icon: appInfo.icon, badge: badge)
        item.button?.toolTip = appInfo.name
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let entry = statusItems.first(where: { $0.value.button == sender }),
              let event = NSApp.currentEvent else { return }

        let bundleID = entry.key

        if event.modifierFlags.contains(.option) {
            configWindowShower?()
        } else {
            openApp(bundleID: bundleID)
        }
    }

    private func openApp(bundleID: String) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return }
        let config = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.openApplication(at: url, configuration: config) { _, _ in }
    }

    @objc private func showConfigFromMenu() {
        configWindowShower?()
    }

    private func compositeIcon(icon: NSImage?, badge: Int) -> NSImage {
        let iconW: CGFloat = 18
        let iconH: CGFloat = 18
        let barH: CGFloat = NSStatusBar.system.thickness
        let spacing: CGFloat = 2
        let badgeH: CGFloat = barH - 6
        let badgeW: CGFloat = badge > 0 ? 14 : 0
        let width: CGFloat = iconW + spacing + badgeW

        let composite = NSImage(size: NSSize(width: width, height: barH), flipped: false) { _ in
            let iconY = (barH - iconH) / 2
            let iconRect = NSRect(x: 1, y: iconY, width: iconW, height: iconH)

            if let icon {
                icon.draw(in: iconRect)
            }

            if badge > 0 {
                let badgeText = badge > 99 ? "99+" : "\(badge)"
                let fontSize: CGFloat = badge > 99 ? 7 : 9
                let textAttrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: fontSize, weight: .bold),
                    .foregroundColor: NSColor.white
                ]
                let textSize = badgeText.size(withAttributes: textAttrs)
                let pillW = max(textSize.width + 4, badgeH)

                let badgeX = iconW + spacing
                let badgeY = (barH - badgeH) / 2 + 1
                let badgeRect = NSRect(x: badgeX, y: badgeY, width: pillW, height: badgeH)

                let path = NSBezierPath(roundedRect: badgeRect, xRadius: badgeH / 2, yRadius: badgeH / 2)
                NSColor.systemRed.setFill()
                path.fill()

                let textX = badgeRect.midX - textSize.width / 2
                let textY = badgeRect.midY - textSize.height / 2
                badgeText.draw(at: NSPoint(x: textX, y: textY), withAttributes: textAttrs)
            }

            return true
        }

        composite.isTemplate = false
        return composite
    }
}
