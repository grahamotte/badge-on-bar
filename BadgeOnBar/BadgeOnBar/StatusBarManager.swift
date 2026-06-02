import AppKit

private let statusItemLength: CGFloat = 22
private let iconSize: CGFloat = 22
private let demoBundleID = "__demo__"

private extension NSImage {
    func grayOut() -> NSImage? {
        guard let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        guard let grayscale = NSBitmapImageRep(cgImage: cgImage).converting(to: .genericGray, renderingIntent: .default) else { return nil }
        let grayImage = NSImage(size: size)
        grayImage.addRepresentation(grayscale)
        return grayImage
    }
}

@MainActor
final class StatusBarManager {
    private let settings: AppSettings
    private let monitor: BadgeMonitor
    private var items: [String: NSStatusItem] = [:]
    var onShowConfig: (() -> Void)?

    init(settings: AppSettings, monitor: BadgeMonitor) {
        self.settings = settings
        self.monitor = monitor
        monitor.onUpdate = { [weak self] in self?.sync() }
        settings.onChanged = { [weak self] in self?.sync() }
        sync()
    }

    func sync() {
        let monitored = settings.monitoredBundleIDs

        for id in items.keys where id != demoBundleID && !monitored.contains(id) {
            NSStatusBar.system.removeStatusItem(items[id]!)
            items[id] = nil
        }

        for bundleID in monitored {
            let running = monitor.availableApps.contains { $0.bundleID == bundleID }
            let badge = monitor.badges[bundleID] ?? 0
            let appInfo = monitor.availableApps.first { $0.bundleID == bundleID }
            let (name, icon) = resolve(bundleID, runningApp: appInfo)

            if let item = items[bundleID] {
                configure(item, name: name, icon: icon, running: running, badge: badge)
            } else {
                let item = NSStatusBar.system.statusItem(withLength: statusItemLength)
                item.autosaveName = "BadgeOnBar_\(bundleID)"
                configure(item, name: name, icon: icon, running: running, badge: badge)
                let btn = item.button!
                btn.target = self
                btn.action = #selector(clicked(_:))
                btn.sendAction(on: [.leftMouseUp, .rightMouseUp])
                items[bundleID] = item
            }
        }

        if settings.demoModeEnabled {
            let demoIcon = NSImage(named: NSImage.applicationIconName)
            let badge = settings.demoBadgeCount
            if let item = items[demoBundleID] {
                configure(item, name: "Demo", icon: demoIcon, running: true, badge: badge)
            } else {
                let item = NSStatusBar.system.statusItem(withLength: statusItemLength)
                item.autosaveName = "BadgeOnBar_\(demoBundleID)"
                configure(item, name: "Demo", icon: demoIcon, running: true, badge: badge)
                let btn = item.button!
                btn.target = self
                btn.action = #selector(clicked(_:))
                btn.sendAction(on: [.leftMouseUp, .rightMouseUp])
                items[demoBundleID] = item
            }
        } else if let item = items[demoBundleID] {
            NSStatusBar.system.removeStatusItem(item)
            items[demoBundleID] = nil
        }
    }

    private func configure(_ item: NSStatusItem, name: String, icon: NSImage?, running: Bool, badge: Int) {
        let btn = item.button!
        btn.image = drawMenuBarIcon(icon: icon, badge: badge)
        btn.image?.isTemplate = false
        btn.imagePosition = .imageOnly
        btn.alphaValue = running ? 1 : 0.35
        btn.title = ""
        btn.attributedTitle = NSAttributedString()
        item.length = statusItemLength
        btn.toolTip = badge > 0 ? "\(name): \(min(badge, 99))" : name
    }

    @objc private func clicked(_ sender: NSStatusBarButton) {
        guard let (id, _) = items.first(where: { $0.value.button == sender }) else { return }
        if let event = NSApp.currentEvent,
           event.type == .rightMouseUp || event.modifierFlags.contains(.option) {
            onShowConfig?()
            return
        }
        if id == demoBundleID { return }
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()) { _, _ in }
        }
    }

    private func drawMenuBarIcon(icon: NSImage?, badge: Int) -> NSImage? {
        guard let icon else { return nil }
        let canvas = NSSize(width: iconSize, height: iconSize)
        let drawIconSize = badge > 0 ? iconSize - 2 : iconSize
        let iconRect = NSRect(x: 0, y: 0, width: drawIconSize, height: drawIconSize)
        return NSImage(size: canvas, flipped: false) { _ in
            if badge > 0 {
                icon.draw(in: iconRect)
                self.drawBadgeDot(count: badge, canvasSize: canvas)
            } else {
                (icon.grayOut() ?? icon).draw(in: iconRect)
            }
            return true
        }
    }

    private func drawBadgeDot(count: Int, canvasSize: NSSize) {
        let text = "\(min(count, 99))"
        let font = NSFont.boldSystemFont(ofSize: 8)
        let attr: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.white]
        let textSize = (text as NSString).size(withAttributes: attr)
        let diameter = max(textSize.width, textSize.height) + 5
        let badgeSize = NSSize(width: diameter, height: diameter)

        let badgeOrigin = NSPoint(x: canvasSize.width - badgeSize.width,
                                   y: canvasSize.height - badgeSize.height)
        let oval = NSRect(origin: badgeOrigin, size: badgeSize)

        NSColor.systemRed.withAlphaComponent(0.9).setFill()
        NSBezierPath(ovalIn: oval).fill()

        let tx = oval.minX + (diameter - textSize.width) / 2
        let ty = oval.minY + (diameter - textSize.height) / 2
        (text as NSString).draw(at: NSPoint(x: tx, y: ty), withAttributes: attr)
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
