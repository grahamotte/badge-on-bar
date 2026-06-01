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
        let size = NSSize(width: 28, height: 22)
        let composite = NSImage(size: size, flipped: false) { rect in
            if let icon {
                let iconSize = NSSize(width: 18, height: 18)
                let iconRect = NSRect(
                    x: 0,
                    y: (size.height - iconSize.height) / 2,
                    width: iconSize.width,
                    height: iconSize.height
                )
                icon.draw(in: iconRect, from: .zero, operation: .sourceOver, fraction: 1.0)
            }

            if badge > 0 {
                let badgeText = badge > 99 ? "99+" : "\(badge)"
                let fontSize: CGFloat = badge > 99 ? 7 : 9

                let textAttributes: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: fontSize, weight: .bold),
                    .foregroundColor: NSColor.white
                ]
                let textSize = badgeText.size(withAttributes: textAttributes)

                let badgeWidth = max(textSize.width + 4, 10)
                let badgeHeight: CGFloat = 11
                let badgeX = icon != nil ? 18.0 : -2.0
                let badgeY = size.height - badgeHeight - 1
                let badgeRect = NSRect(x: badgeX, y: badgeY, width: badgeWidth, height: badgeHeight)

                let badgePath = NSBezierPath(
                    roundedRect: badgeRect,
                    xRadius: badgeHeight / 2,
                    yRadius: badgeHeight / 2
                )
                NSColor.systemRed.setFill()
                badgePath.fill()

                let textRect = NSRect(
                    x: badgeRect.midX - textSize.width / 2,
                    y: badgeRect.midY - textSize.height / 2,
                    width: textSize.width,
                    height: textSize.height
                )
                badgeText.draw(in: textRect, withAttributes: textAttributes)
            }

            return true
        }

        composite.isTemplate = false
        return composite
    }
}
