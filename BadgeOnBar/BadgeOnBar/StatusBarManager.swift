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
        let currentIDs = Set(statusItems.keys)

        for bundleID in currentIDs where !monitored.contains(bundleID) {
            removeStatusItem(for: bundleID)
        }

        for bundleID in monitored {
            let info = lookupAppInfo(for: bundleID)
            let isRunning = monitor.availableApps.contains(where: { $0.bundleID == bundleID })
            let badge = monitor.badges[bundleID] ?? 0

            if let item = statusItems[bundleID] {
                item.button?.image = renderIcon(icon: info.icon, badge: badge, isRunning: isRunning)
                item.button?.toolTip = info.name
            } else {
                createStatusItem(for: bundleID, icon: info.icon, name: info.name, badge: badge, isRunning: isRunning)
            }
        }
    }

    private func createStatusItem(for bundleID: String, icon: NSImage?, name: String, badge: Int, isRunning: Bool) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = item.button {
            button.image = renderIcon(icon: icon, badge: badge, isRunning: isRunning)
            button.imagePosition = .imageOnly
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.toolTip = name
            button.sendAction(on: .leftMouseUp)
        }

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

        item.menu = menu
        statusItems[bundleID] = item
    }

    private func removeStatusItem(for bundleID: String) {
        if let item = statusItems[bundleID] {
            NSStatusBar.system.removeStatusItem(item)
        }
        statusItems.removeValue(forKey: bundleID)
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

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let entry = statusItems.first(where: { $0.value.button == sender }) else { return }
        let bundleID = entry.key

        if NSApp.currentEvent?.modifierFlags.contains(.option) ?? false {
            configWindowShower?()
        } else {
            openApp(bundleID: bundleID)
        }
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
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()) { _, _ in }
    }

    private func renderIcon(icon: NSImage?, badge: Int, isRunning: Bool) -> NSImage {
        let barH = NSStatusBar.system.thickness
        let iconW: CGFloat = 18
        let iconH: CGFloat = 18
        let padding: CGFloat = 2
        let badgeW: CGFloat = badge > 0 ? 16 : 0
        let totalW: CGFloat = padding + iconW + padding + badgeW
        let size = NSSize(width: totalW, height: barH)

        let image: NSImage
        if #available(macOS 14.0, *) {
            image = NSImage(size: size, flipped: false) { _ in
                self.drawIconAndBadge(icon: icon, badge: badge, isRunning: isRunning, size: size)
                return true
            }
        } else {
            image = NSImage(size: size)
            image.lockFocus()
            drawIconAndBadge(icon: icon, badge: badge, isRunning: isRunning, size: size)
            image.unlockFocus()
        }
        image.isTemplate = false
        return image
    }

    private func drawIconAndBadge(icon: NSImage?, badge: Int, isRunning: Bool, size: NSSize) {
        let iconW: CGFloat = 18
        let iconH: CGFloat = 18
        let padding: CGFloat = 2
        let iconY = (size.height - iconH) / 2
        let iconRect = NSRect(x: padding, y: iconY, width: iconW, height: iconH)
        let alpha: CGFloat = isRunning ? 1.0 : 0.35

        if let icon {
            let srcRect = NSRect(origin: .zero, size: icon.size)
            icon.draw(in: iconRect, from: srcRect, operation: .sourceOver, fraction: alpha)
        } else {
            NSColor.tertiaryLabelColor.withAlphaComponent(alpha).setFill()
            NSBezierPath(roundedRect: iconRect.insetBy(dx: 4, dy: 4), xRadius: 4, yRadius: 4).fill()
        }

        guard badge > 0, isRunning else { return }

        let badgeText = badge > 99 ? "99+" : "\(badge)"
        let fontSize: CGFloat = badge > 99 ? 7 : 9
        let textAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize, weight: .bold),
            .foregroundColor: NSColor.white
        ]
        let textSize = badgeText.size(withAttributes: textAttrs)

        let pillH: CGFloat = size.height - 8
        let pillW = max(textSize.width + 4, pillH)
        let pillX = padding + iconW + padding
        let pillY = (size.height - pillH) / 2
        let pillRect = NSRect(x: pillX, y: pillY, width: pillW, height: pillH)

        let path = NSBezierPath(roundedRect: pillRect, xRadius: pillH / 2, yRadius: pillH / 2)
        NSColor.systemRed.setFill()
        path.fill()

        let textX = pillRect.midX - textSize.width / 2
        let textY = pillRect.midY - textSize.height / 2
        badgeText.draw(at: NSPoint(x: textX, y: textY), withAttributes: textAttrs)
    }
}
