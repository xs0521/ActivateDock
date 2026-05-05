//
//  AppIconButton.swift
//  ActivateDock
//

import Cocoa

final class AppIconButton: NSButton {
    let app: RunningApp

    private static let buttonSize: CGFloat = 72
    private static let iconSize: CGFloat = 56

    private let iconView = NSImageView()
    private var trackingArea: NSTrackingArea?
    private var isHovered = false
    private var isFocused = false

    init(app: RunningApp) {
        self.app = app
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        isBordered = false
        title = ""
        wantsLayer = true
        layer?.cornerRadius = 12
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.clear.cgColor
        layer?.backgroundColor = NSColor.clear.cgColor

        let icon = app.app.icon?.copy() as? NSImage
        icon?.size = NSSize(width: Self.iconSize, height: Self.iconSize)
        iconView.image = icon
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.wantsLayer = true
        addSubview(iconView)

        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: Self.buttonSize),
            heightAnchor.constraint(equalToConstant: Self.buttonSize),

            iconView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: Self.iconSize),
            iconView.heightAnchor.constraint(equalToConstant: Self.iconSize)
        ])
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

    func setFocused(_ focused: Bool) {
        guard isFocused != focused else { return }
        isFocused = focused
        applyAppearance()
    }

    private func applyAppearance() {
        let bg: CGColor
        let border: CGColor

        if isFocused {
            bg = NSColor.controlAccentColor.withAlphaComponent(0.22).cgColor
            border = NSColor.controlAccentColor.cgColor
        } else if isHovered {
            bg = NSColor.labelColor.withAlphaComponent(0.10).cgColor
            border = NSColor.clear.cgColor
        } else {
            bg = NSColor.clear.cgColor
            border = NSColor.clear.cgColor
        }

        CATransaction.begin()
        CATransaction.setAnimationDuration(0.15)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeOut))
        layer?.backgroundColor = bg
        layer?.borderColor = border
        CATransaction.commit()
    }
}
