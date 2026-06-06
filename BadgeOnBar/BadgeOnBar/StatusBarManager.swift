import AppKit

private let statusItemLength: CGFloat = 18
private let iconSize: CGFloat = 18
private let badgeViewTag = 9731
private let badgeRed = NSColor.systemRed.withAlphaComponent(0.9)

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
        removeBadge(from: btn)
        btn.image = statusIcon(name: name, icon: icon, badge: badge, bundleID: bundleID)
        btn.imagePosition = .imageOnly
        btn.title = ""
        btn.attributedTitle = NSAttributedString()
        item.length = statusItemLength

        if let overlay = badgeOverlay(for: badge, bundleID: bundleID) {
            addBadge(overlay, to: btn)
        }

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

    // MARK: - Rendering

    private enum BadgeOverlay {
        case dot
        case text(String)
        case centerDot

        var isCornerDot: Bool {
            if case .dot = self { return true }
            return false
        }
    }

    private func statusIcon(name: String, icon: NSImage?, badge: Int, bundleID: String) -> NSImage? {
        if let symbolName = settings.symbolOverride(for: bundleID),
           let symbol = NSImage(systemSymbolName: symbolName, accessibilityDescription: name)?
            .withSymbolConfiguration(.init(pointSize: iconSize, weight: .medium)) {
            let image = fittedImage(symbol)
            image.isTemplate = true
            return image
        }

        guard let icon else { return nil }
        let image = fittedImage(icon)
        return badge == 0 ? image.grayOut() ?? image : image
    }

    private func badgeOverlay(for badge: Int, bundleID: String) -> BadgeOverlay? {
        guard badge > 0 || badge == -1 else { return nil }
        if settings.isDotBadge(bundleID) { return .dot }
        if badge == -1 { return .centerDot }
        return .text("\(min(badge, 99))")
    }

    private func addBadge(_ overlay: BadgeOverlay, to button: NSStatusBarButton) {
        let badgeImage = Self.badgeImage(overlay)
        let diameter = badgeImage.size.width
        let margin: CGFloat = 1
        let btnW = max(button.bounds.width, statusItemLength)
        let btnH = max(button.bounds.height, iconSize)
        let imgX = (btnW - iconSize) / 2
        let imgY = (btnH - iconSize) / 2

        let frame: NSRect
        if overlay.isCornerDot {
            frame = NSRect(x: imgX + iconSize - diameter - margin,
                           y: imgY + margin,
                           width: diameter,
                           height: diameter)
        } else {
            frame = NSRect(x: imgX + (iconSize - diameter) / 2,
                           y: imgY + (iconSize - diameter) / 2,
                           width: diameter,
                           height: diameter)
        }

        let imageView = NSImageView(frame: frame)
        imageView.tag = badgeViewTag
        imageView.image = badgeImage
        imageView.imageScaling = .scaleNone
        button.addSubview(imageView)
    }

    private func removeBadge(from button: NSStatusBarButton) {
        button.subviews.first(where: { $0.tag == badgeViewTag })?.removeFromSuperview()
    }

    private func fittedImage(_ source: NSImage) -> NSImage {
        let canvas = NSSize(width: iconSize, height: iconSize)
        let rect = aspectFitRect(for: source, in: NSRect(origin: .zero, size: canvas))
        return NSImage(size: canvas, flipped: false) { _ in
            source.draw(in: rect)
            return true
        }
    }

    private static func badgeImage(_ overlay: BadgeOverlay) -> NSImage {
        if case .dot = overlay {
            let diameter: CGFloat = 8
            return NSImage(size: NSSize(width: diameter, height: diameter), flipped: false) { rect in
                badgeRed.setFill()
                NSBezierPath(ovalIn: rect).fill()
                return true
            }
        }

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 8),
            .foregroundColor: NSColor.white
        ]
        let text: String? = {
            if case .text(let text) = overlay { return text }
            return nil
        }()
        let sizingText = text ?? "1"
        let textSize = (sizingText as NSString).size(withAttributes: attrs)
        let diameter = max(10, max(textSize.width, textSize.height) + 4)

        return NSImage(size: NSSize(width: diameter, height: diameter), flipped: false) { rect in
            badgeRed.setFill()
            NSBezierPath(ovalIn: rect).fill()

            switch overlay {
            case .centerDot:
                let dotDiameter: CGFloat = 3
                let dotRect = NSRect(x: rect.midX - dotDiameter / 2,
                                     y: rect.midY - dotDiameter / 2,
                                     width: dotDiameter,
                                     height: dotDiameter)
                NSColor.white.setFill()
                NSBezierPath(ovalIn: dotRect).fill()
            case .text(let text):
                let point = NSPoint(x: rect.midX - textSize.width / 2, y: rect.midY - textSize.height / 2)
                (text as NSString).draw(at: point, withAttributes: attrs)
            case .dot:
                break
            }
            return true
        }
    }

    private func aspectFitRect(for image: NSImage, in rect: NSRect) -> NSRect {
        guard image.size.width > 0, image.size.height > 0 else { return rect }
        let scale = min(rect.width / image.size.width, rect.height / image.size.height)
        let size = NSSize(width: image.size.width * scale, height: image.size.height * scale)
        return NSRect(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2, width: size.width, height: size.height)
    }

    private func resolve(_ bundleID: String, runningApp: AppBadgeInfo?) -> (String, NSImage?) {
        if let runningApp, runningApp.icon != nil { return (runningApp.name, runningApp.icon) }
        let app = AppBadgeInfo.fromBundleID(bundleID)
        return (app?.name ?? bundleID, app?.icon)
    }
}
