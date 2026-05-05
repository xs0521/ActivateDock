//
//  AppIconButton.swift
//  ActivateDock
//

import Cocoa

final class HoverableBadgeButton: NSButton {
    override func hitTest(_ point: NSPoint) -> NSView? {
        guard alphaValue > 0.05 else { return nil }
        return super.hitTest(point)
    }
}

final class AppIconButton: NSButton {
    let app: RunningApp

    private static let buttonSize: CGFloat = 72
    private static let iconSize: CGFloat = 56
    private static let badgeSize: CGFloat = 18

    private let iconView = NSImageView()
    private let plusBadge = HoverableBadgeButton()
    private var trackingArea: NSTrackingArea?
    private var isHovered = false

    var onDragStart: ((NSPoint) -> Void)?
    var onDragMove: ((NSPoint) -> Void)?
    var onDragEnd: ((NSPoint) -> Void)?
    var onPlusTapped: (() -> Void)?

    private static let dragThreshold: CGFloat = 4

    init(app: RunningApp) {
        self.app = app
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        isBordered = false
        title = ""
        wantsLayer = true
        layer?.cornerRadius = 12
        layer?.backgroundColor = NSColor.clear.cgColor

        let icon = app.app.icon?.copy() as? NSImage
        icon?.size = NSSize(width: Self.iconSize, height: Self.iconSize)
        iconView.image = icon
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.wantsLayer = true
        addSubview(iconView)

        setupPlusBadge()

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: Self.buttonSize),
            heightAnchor.constraint(equalToConstant: Self.buttonSize),

            iconView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: Self.iconSize),
            iconView.heightAnchor.constraint(equalToConstant: Self.iconSize),

            plusBadge.widthAnchor.constraint(equalToConstant: Self.badgeSize),
            plusBadge.heightAnchor.constraint(equalToConstant: Self.badgeSize),
            plusBadge.centerXAnchor.constraint(equalTo: iconView.trailingAnchor, constant: -8),
            plusBadge.centerYAnchor.constraint(equalTo: iconView.topAnchor, constant: 8)
        ])
    }

    private func setupPlusBadge() {
        plusBadge.translatesAutoresizingMaskIntoConstraints = false
        plusBadge.isBordered = false
        plusBadge.title = ""
        plusBadge.imagePosition = .imageOnly
        plusBadge.contentTintColor = NSColor.white
        let cfg = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        plusBadge.image = NSImage(systemSymbolName: "plus", accessibilityDescription: "新建分类")?
            .withSymbolConfiguration(cfg)
        plusBadge.wantsLayer = true
        plusBadge.layer?.isOpaque = false
        plusBadge.layer?.backgroundColor = NSColor.clear.cgColor
        plusBadge.layer?.masksToBounds = false
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.6)
        shadow.shadowOffset = NSSize(width: 0, height: -1)
        shadow.shadowBlurRadius = 3
        plusBadge.shadow = shadow
        plusBadge.alphaValue = 0
        plusBadge.target = self
        plusBadge.action = #selector(handlePlusTap(_:))
        addSubview(plusBadge)
    }

    @objc private func handlePlusTap(_ sender: NSButton) {
        onPlusTapped?()
    }

    required init?(coder: NSCoder) { nil }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        applyAppearance()
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        applyAppearance()
    }

    func clearHoverState() {
        isHovered = false
        plusBadge.layer?.removeAllAnimations()
        plusBadge.alphaValue = 0
        layer?.removeAllAnimations()
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    private func applyAppearance() {
        let bg: CGColor = isHovered
            ? NSColor.labelColor.withAlphaComponent(0.10).cgColor
            : NSColor.clear.cgColor

        CATransaction.begin()
        CATransaction.setAnimationDuration(0.15)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeOut))
        layer?.backgroundColor = bg
        CATransaction.commit()

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            plusBadge.animator().alphaValue = isHovered ? 1 : 0
        }
    }

    override func mouseDown(with event: NSEvent) {
        let start = event.locationInWindow
        var dragging = false
        guard let win = window else { return }

        while true {
            guard let next = win.nextEvent(matching: [.leftMouseUp, .leftMouseDragged]) else { return }
            let p = next.locationInWindow
            switch next.type {
            case .leftMouseDragged:
                if !dragging {
                    if abs(p.x - start.x) > Self.dragThreshold || abs(p.y - start.y) > Self.dragThreshold {
                        dragging = true
                        onDragStart?(p)
                    }
                } else {
                    onDragMove?(p)
                }
            case .leftMouseUp:
                if dragging {
                    onDragEnd?(p)
                } else if let action = action, let target = target {
                    NSApp.sendAction(action, to: target, from: self)
                }
                return
            default:
                break
            }
        }
    }
}
