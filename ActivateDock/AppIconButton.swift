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

    static let buttonWidth: CGFloat = 72
    static let buttonHeight: CGFloat = 72
    private static let iconSize: CGFloat = 56
    private static let badgeSize: CGFloat = 18
    private static let memoryLabelHeight: CGFloat = 12
    private static let memoryBackdropMinWidth: CGFloat = 46

    private let iconView = NSImageView()
    private let plusBadge = HoverableBadgeButton()
    private let closeBadge = HoverableBadgeButton()
    private let memoryBackdrop = NSView()
    private let memoryLabel = NSTextField(labelWithString: "")
    private var trackingArea: NSTrackingArea?
    private var isHovered = false
    private let pid: pid_t

    private static let backdropColor = NSColor.black.withAlphaComponent(0.42).cgColor
    private static let breathLowColor = NSColor.black.withAlphaComponent(0.18).cgColor
    private static let breathHighColor = NSColor.black.withAlphaComponent(0.55).cgColor

    private var isLoading = false {
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

    private func setupMemoryLabel() {
        memoryBackdrop.translatesAutoresizingMaskIntoConstraints = false
        memoryBackdrop.wantsLayer = true
        memoryBackdrop.layer?.cornerRadius = (Self.memoryLabelHeight + 2) / 2
        memoryBackdrop.layer?.backgroundColor = Self.backdropColor
        memoryBackdrop.layer?.masksToBounds = false
        let backdropShadow = NSShadow()
        backdropShadow.shadowColor = NSColor.black.withAlphaComponent(0.45)
        backdropShadow.shadowOffset = NSSize(width: 0, height: -1)
        backdropShadow.shadowBlurRadius = 2.5
        memoryBackdrop.shadow = backdropShadow
        addSubview(memoryBackdrop)

        memoryLabel.translatesAutoresizingMaskIntoConstraints = false
        memoryLabel.font = .monospacedDigitSystemFont(ofSize: 9.5, weight: .medium)
        memoryLabel.textColor = .white
        memoryLabel.alignment = .center
        memoryLabel.lineBreakMode = .byClipping
        memoryLabel.maximumNumberOfLines = 1
        memoryLabel.cell?.usesSingleLineMode = true
        memoryLabel.stringValue = ""
        memoryLabel.setContentHuggingPriority(.required, for: .horizontal)
        memoryLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        memoryBackdrop.addSubview(memoryLabel)
    }

    private func startMemoryTracking() {
        guard pid > 0 else { return }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryUpdate(_:)),
            name: MemoryMonitor.didUpdateNotification,
            object: nil
        )
        MemoryMonitor.shared.track(pid)
        if let cached = MemoryMonitor.shared.lastReading(for: pid) {
            memoryLabel.stringValue = MemoryProbe.format(cached)
        } else {
            isLoading = true
        }
    }

    @objc private func handleMemoryUpdate(_ note: Notification) {
        guard let info = note.userInfo,
              let updated = info[MemoryMonitor.pidKey] as? pid_t,
              updated == pid else { return }
        if let bytes = info[MemoryMonitor.bytesKey] as? UInt64 {
            isLoading = false
            memoryLabel.stringValue = MemoryProbe.format(bytes)
        } else {
            memoryLabel.stringValue = ""
            isLoading = true
        }
    }

    private func startLoadingAnimation() {
        memoryLabel.stringValue = ""
        let breath = CABasicAnimation(keyPath: "backgroundColor")
        breath.fromValue = Self.breathLowColor
        breath.toValue = Self.breathHighColor
        breath.duration = 0.95
        breath.autoreverses = true
        breath.repeatCount = .infinity
        breath.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        memoryBackdrop.layer?.add(breath, forKey: "breath")
    }

    private func stopLoadingAnimation() {
        memoryBackdrop.layer?.removeAnimation(forKey: "breath")
    }

    private func setupPlusBadge() {
        plusBadge.translatesAutoresizingMaskIntoConstraints = false
        plusBadge.isBordered = false
        plusBadge.title = ""
        plusBadge.imagePosition = .imageOnly
        plusBadge.contentTintColor = NSColor.white
        let cfg = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        plusBadge.image = NSImage(systemSymbolName: "folder.fill", accessibilityDescription: "new category")?
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

    private func setupCloseBadge() {
        closeBadge.translatesAutoresizingMaskIntoConstraints = false
        closeBadge.isBordered = false
        closeBadge.title = ""
        closeBadge.imagePosition = .imageOnly
        closeBadge.contentTintColor = NSColor.white
        let cfg = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
        closeBadge.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "quit")?
            .withSymbolConfiguration(cfg)
        closeBadge.wantsLayer = true
        closeBadge.layer?.isOpaque = false
        closeBadge.layer?.backgroundColor = NSColor.clear.cgColor
        closeBadge.layer?.masksToBounds = false
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.6)
        shadow.shadowOffset = NSSize(width: 0, height: -1)
        shadow.shadowBlurRadius = 3
        closeBadge.shadow = shadow
        closeBadge.alphaValue = 0
        closeBadge.target = self
        closeBadge.action = #selector(handleCloseTap(_:))
        addSubview(closeBadge)
    }

    @objc private func handleCloseTap(_ sender: NSButton) {
        app.app.terminate()
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
