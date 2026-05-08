//
//  AppIconButton+Badges.swift
//  ActivateDock
//

import Cocoa

final class HoverableBadgeButton: NSButton {
    override func hitTest(_ point: NSPoint) -> NSView? {
        guard alphaValue > 0.05 else { return nil }
        return super.hitTest(point)
    }
}

extension AppIconButton {
    func setupPlusBadge() {
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

    func setupCloseBadge() {
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
}
