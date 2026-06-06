import AppKit

private let statusItemLength: CGFloat = 18
private let iconSize: CGFloat = 18

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

        DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.sync()
            }
        }

        sync()
    }

    func sync() {
        let monitored = settings.monitoredBundleIDs

        for id in items.keys where !monitored.contains(id) {
            if let item = items[id] {
                NSStatusBar.system.removeStatusItem(item)
            }
            items[id] = nil
        }

        for bundleID in monitored {
            let badge = settings.demoBadgeOverride ?? monitor.badges[bundleID] ?? 0
            let appInfo = monitor.availableApps.first { $0.bundleID == bundleID }
            let (name, icon) = resolve(bundleID, runningApp: appInfo)
            configure(item(for: bundleID), name: name, icon: icon, badge: badge, bundleID: bundleID)
        }
    }

    private func item(for bundleID: String) -> NSStatusItem {
        if let item = items[bundleID] { return item }

        let item = NSStatusBar.system.statusItem(withLength: statusItemLength)
        item.autosaveName = "BadgeOnBar_\(bundleID)"
        let btn = item.button!
        btn.target = self
        btn.action = #selector(clicked(_:))
        btn.sendAction(on: [.leftMouseUp, .rightMouseUp])
        items[bundleID] = item
        return item
    }

    private func configure(_ item: NSStatusItem, name: String, icon: NSImage?, badge: Int, bundleID: String) {
        let btn = item.button!
        let dotBadge = settings.isDotBadge(bundleID)
        let isDark = btn.effectiveAppearance.name.rawValue.lowercased().contains("dark")

        if let symbolName = settings.symbolOverride(for: bundleID),
           let symbolIcon = NSImage(systemSymbolName: symbolName, accessibilityDescription: name)?
            .withSymbolConfiguration(.init(pointSize: iconSize, weight: .medium)) {

            symbolIcon.isTemplate = true
            let canvasRect = NSRect(origin: .zero, size: NSSize(width: iconSize, height: iconSize))
            let fitRect = aspectFitRect(for: symbolIcon, in: canvasRect)
            let fillColor: NSColor = isDark ? .white : .black

            btn.image = NSImage(size: canvasRect.size, flipped: false) { _ in
                fillColor.setFill()
                symbolIcon.draw(in: fitRect)

                if badge > 0 || badge == -1 {
                    if dotBadge {
                        Self.drawDotOnly(canvasSize: canvasRect.size)
                    } else if badge == -1 {
                        Self.drawInterpunct(canvasSize: canvasRect.size)
                    } else {
                        Self.drawBadgeDot(count: badge, canvasSize: canvasRect.size)
                    }
                }
                return true
            }
        } else if let icon {
            let canvasRect = NSRect(origin: .zero, size: NSSize(width: iconSize, height: iconSize))
            btn.image = compositeIcon(icon: icon, badge: badge, iconRect: canvasRect, dotBadge: dotBadge)
        } else {
            btn.image = nil
        }

        btn.imagePosition = .imageOnly
        btn.title = ""
        btn.attributedTitle = NSAttributedString()
        item.length = statusItemLength
        let tip: String = {
            if badge > 0 { return "\(name): \(min(badge, 99))" }
            if badge == -1 { return "\(name): \u{00B7}" }
            return name
        }()
        btn.toolTip = tip
    }

    @objc private func clicked(_ sender: NSStatusBarButton) {
        guard let (id, _) = items.first(where: { $0.value.button == sender }) else { return }
        if let event = NSApp.currentEvent,
           event.type == .rightMouseUp || event.modifierFlags.contains(.option) {
            onShowConfig?()
            return
        }
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()) { _, _ in }
        }
    }

    // MARK: - Drawing helpers

    private func aspectFitRect(for image: NSImage, in rect: NSRect) -> NSRect {
        guard image.size.width > 0, image.size.height > 0 else { return rect }
        let scale = min(rect.width / image.size.width, rect.height / image.size.height)
        let size = NSSize(width: image.size.width * scale, height: image.size.height * scale)
        return NSRect(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2, width: size.width, height: size.height)
    }

    private func compositeIcon(icon: NSImage?, badge: Int, iconRect: NSRect, dotBadge: Bool) -> NSImage? {
        guard let icon else { return nil }
        let canvas = NSSize(width: iconSize, height: iconSize)
        return NSImage(size: canvas, flipped: false) { _ in
            if badge == 0 {
                (self.renderedIcon(icon, in: iconRect, canvas: canvas).grayOut() ?? icon).draw(in: NSRect(origin: .zero, size: canvas))
            } else {
                icon.draw(in: iconRect)
            }

            if badge > 0 || badge == -1 {
                if dotBadge {
                    Self.drawDotOnly(canvasSize: canvas)
                } else if badge == -1 {
                    Self.drawInterpunct(canvasSize: canvas)
                } else {
                    Self.drawBadgeDot(count: badge, canvasSize: canvas)
                }
            }
            return true
        }
    }

    private func renderedIcon(_ icon: NSImage, in rect: NSRect, canvas: NSSize) -> NSImage {
        NSImage(size: canvas, flipped: false) { _ in
            icon.draw(in: rect)
            return true
        }
    }

    private static func drawDotOnly(canvasSize: NSSize) {
        let diameter: CGFloat = 8
        let margin: CGFloat = 1
        let origin = NSPoint(x: canvasSize.width - diameter - margin,
                             y: canvasSize.height - diameter - margin)
        let oval = NSRect(origin: origin, size: NSSize(width: diameter, height: diameter))
        NSColor.systemRed.withAlphaComponent(0.9).setFill()
        NSBezierPath(ovalIn: oval).fill()
    }

    private static func drawInterpunct(canvasSize: NSSize) {
        let text = "\u{00B7}"
        let font = NSFont.boldSystemFont(ofSize: 8)
        let attr: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.white]
        let textSize = (text as NSString).size(withAttributes: attr)
        let diameter = max(textSize.width, textSize.height) + 4
        let badgeSize = NSSize(width: diameter, height: diameter)

        let badgeOrigin = NSPoint(x: (canvasSize.width - badgeSize.width) / 2,
                                   y: (canvasSize.height - badgeSize.height) / 2)
        let oval = NSRect(origin: badgeOrigin, size: badgeSize)

        NSColor.systemRed.withAlphaComponent(0.9).setFill()
        NSBezierPath(ovalIn: oval).fill()

        let tx = oval.minX + (diameter - textSize.width) / 2
        let ty = oval.minY + (diameter - textSize.height) / 2
        (text as NSString).draw(at: NSPoint(x: tx, y: ty), withAttributes: attr)
    }

    private static func drawBadgeDot(count: Int, canvasSize: NSSize) {
        let text = "\(min(count, 99))"
        let font = NSFont.boldSystemFont(ofSize: 8)
        let attr: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.white]
        let textSize = (text as NSString).size(withAttributes: attr)
        let diameter = max(textSize.width, textSize.height) + 4
        let badgeSize = NSSize(width: diameter, height: diameter)

        let badgeOrigin = NSPoint(x: (canvasSize.width - badgeSize.width) / 2,
                                   y: (canvasSize.height - badgeSize.height) / 2)
        let oval = NSRect(origin: badgeOrigin, size: badgeSize)

        NSColor.systemRed.withAlphaComponent(0.9).setFill()
        NSBezierPath(ovalIn: oval).fill()

        let tx = oval.minX + (diameter - textSize.width) / 2
        let ty = oval.minY + (diameter - textSize.height) / 2
        (text as NSString).draw(at: NSPoint(x: tx, y: ty), withAttributes: attr)
    }

    private func resolve(_ bundleID: String, runningApp: AppBadgeInfo?) -> (String, NSImage?) {
        if let runningApp, runningApp.icon != nil { return (runningApp.name, runningApp.icon) }
        let app = AppBadgeInfo.fromBundleID(bundleID)
        return (app?.name ?? bundleID, app?.icon)
    }
}
