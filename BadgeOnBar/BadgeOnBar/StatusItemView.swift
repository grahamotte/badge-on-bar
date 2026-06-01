import AppKit

final class StatusItemView: NSView {
    var icon: NSImage?
    var badgeCount: Int = 0
    var isRunning: Bool = true
    var onLeftClick: (() -> Void)?
    var onRightClick: (() -> Void)?

    private var trackingArea: NSTrackingArea?

    override func draw(_ dirtyRect: NSRect) {
        let iconSize: CGFloat = 18
        let iconY = (bounds.height - iconSize) / 2
        let iconRect = NSRect(x: 1, y: iconY, width: iconSize, height: iconSize)

        if let icon, isRunning {
            icon.draw(in: iconRect)
        } else if let icon {
            icon.draw(in: iconRect, from: .zero, operation: .sourceOver, fraction: 0.35)
        } else {
            NSColor.tertiaryLabelColor.setFill()
            let path = NSBezierPath(roundedRect: iconRect.insetBy(dx: 4, dy: 4), xRadius: 4, yRadius: 4)
            path.fill()
        }

        if badgeCount > 0, isRunning {
            drawBadge(afterIcon: iconSize + 1)
        }
    }

    private func drawBadge(afterIcon iconRight: CGFloat) {
        let badgeText = badgeCount > 99 ? "99+" : "\(badgeCount)"
        let fontSize: CGFloat = badgeCount > 99 ? 7 : 9
        let textAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize, weight: .bold),
            .foregroundColor: NSColor.white
        ]
        let textSize = badgeText.size(withAttributes: textAttrs)
        let pillH: CGFloat = bounds.height - 8
        let pillW = max(textSize.width + 4, pillH)
        let pillX = iconRight - 2
        let pillY = (bounds.height - pillH) / 2
        let pillRect = NSRect(x: pillX, y: pillY, width: pillW, height: pillH)

        let path = NSBezierPath(roundedRect: pillRect, xRadius: pillH / 2, yRadius: pillH / 2)
        NSColor.systemRed.setFill()
        path.fill()

        let textX = pillRect.midX - textSize.width / 2
        let textY = pillRect.midY - textSize.height / 2
        badgeText.draw(at: NSPoint(x: textX, y: textY), withAttributes: textAttrs)
    }

    override func mouseDown(with event: NSEvent) {
        onLeftClick?()
    }

    override func rightMouseDown(with event: NSEvent) {
        onRightClick?()
    }

    func requiredWidth() -> CGFloat {
        let base: CGFloat = 20
        let badge: CGFloat = badgeCount > 0 ? 16 : 0
        return base + badge
    }
}
