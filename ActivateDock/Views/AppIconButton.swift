//
//  AppIconButton.swift
//  ActivateDock
//

import Cocoa

final class AppIconButton: NSButton {
    let app: RunningApp

    static let buttonWidth: CGFloat = 72
    static let buttonHeight: CGFloat = 72
    static let iconSize: CGFloat = 56
    static let badgeSize: CGFloat = 18
    static let memoryLabelHeight: CGFloat = 12
    static let memoryBackdropMinWidth: CGFloat = 46

    static let backdropColor = NSColor.black.withAlphaComponent(0.42).cgColor
    static let breathLowColor = NSColor.black.withAlphaComponent(0.18).cgColor
    static let breathHighColor = NSColor.black.withAlphaComponent(0.55).cgColor

    let iconView = NSImageView()
    let plusBadge = HoverableBadgeButton()
    let closeBadge = HoverableBadgeButton()
    let memoryBackdrop = NSView()
    let memoryLabel = NSTextField(labelWithString: "")
    let pid: pid_t

    private var trackingArea: NSTrackingArea?
    private var isHovered = false

    var isLoading = false {
        didSet {
            guard oldValue != isLoading else { return }
            isLoading ? startLoadingAnimation() : stopLoadingAnimation()
        }
    }

    var onDragStart: ((NSPoint) -> Void)?
    var onDragMove: ((NSPoint) -> Void)?
    var onDragEnd: ((NSPoint) -> Void)?
    var onPlusTapped: (() -> Void)?

    private static let dragThreshold: CGFloat = 4

    init(app: RunningApp) {
        self.app = app
        self.pid = app.app.processIdentifier
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
        setupCloseBadge()
        setupMemoryLabel()

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: Self.buttonWidth),
            heightAnchor.constraint(equalToConstant: Self.buttonHeight),

            iconView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconView.topAnchor.constraint(equalTo: topAnchor),
            iconView.widthAnchor.constraint(equalToConstant: Self.iconSize),
            iconView.heightAnchor.constraint(equalToConstant: Self.iconSize),

            plusBadge.widthAnchor.constraint(equalToConstant: Self.badgeSize),
            plusBadge.heightAnchor.constraint(equalToConstant: Self.badgeSize),
            plusBadge.centerXAnchor.constraint(equalTo: iconView.trailingAnchor, constant: -4),
            plusBadge.centerYAnchor.constraint(equalTo: iconView.topAnchor, constant: 8),

            closeBadge.widthAnchor.constraint(equalToConstant: Self.badgeSize),
            closeBadge.heightAnchor.constraint(equalToConstant: Self.badgeSize),
            closeBadge.centerXAnchor.constraint(equalTo: iconView.leadingAnchor, constant: 4),
            closeBadge.centerYAnchor.constraint(equalTo: iconView.topAnchor, constant: 8),

            memoryBackdrop.centerXAnchor.constraint(equalTo: centerXAnchor),
            memoryBackdrop.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 1),
            memoryBackdrop.heightAnchor.constraint(equalToConstant: Self.memoryLabelHeight + 2),
            memoryBackdrop.widthAnchor.constraint(greaterThanOrEqualToConstant: Self.memoryBackdropMinWidth),
            memoryBackdrop.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 2),
            memoryBackdrop.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -2),

            memoryLabel.centerYAnchor.constraint(equalTo: memoryBackdrop.centerYAnchor),
            memoryLabel.leadingAnchor.constraint(equalTo: memoryBackdrop.leadingAnchor, constant: 5),
            memoryLabel.trailingAnchor.constraint(equalTo: memoryBackdrop.trailingAnchor, constant: -5)
        ])

        startMemoryTracking()
    }

    deinit {
        if pid > 0 {
            MemoryMonitor.shared.untrack(pid)
        }
        NotificationCenter.default.removeObserver(self)
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
        closeBadge.layer?.removeAllAnimations()
        closeBadge.alphaValue = 0
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
            closeBadge.animator().alphaValue = isHovered ? 1 : 0
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
