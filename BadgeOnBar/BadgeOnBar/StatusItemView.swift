import AppKit

final class StatusItemView: NSView {
    var appIcon: NSImage? {
        didSet { iconView.image = appIcon; needsDisplay = true }
    }
    var badgeCount: Int = 0 {
        didSet { needsDisplay = true }
    }
    var isRunning: Bool = true {
        didSet { iconView.alphaValue = isRunning ? 1.0 : 0.35; needsDisplay = true }
    }
    var onLeftClick: (() -> Void)?
    var onRightClick: (() -> Void)?

    private let iconView: NSImageView = {
        let iv = NSImageView()
        iv.imageScaling = .scaleProportionallyUpOrDown
        return iv
    }()

    override init(frame: NSRect) {
        super.init(frame: frame)
        iconView.frame = NSRect(x: 1, y: (frame.height - 18) / 2, width: 18, height: 18)
        addSubview(iconView)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        if badgeCount > 0, isRunning {
            drawBadge()
        }
    }

    private func drawBadge() {
        let iconRight: CGFloat = 20
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
        let base: CGFloat = 22
        let badge: CGFloat = badgeCount > 0 ? 16 : 0
        return base + badge
    }
}
