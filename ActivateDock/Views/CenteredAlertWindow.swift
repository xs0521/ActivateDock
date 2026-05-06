//
//  CenteredAlertWindow.swift
//  ActivateDock
//

import Cocoa

final class CenteredAlertWindow: NSObject {
    enum Response { case primary, secondary }

    var icon: NSImage?
    var title: String = ""
    var message: String = ""
    var primaryButton: String = "OK"
    var secondaryButton: String?

    private var response: Response = .primary
    private var panel: NSPanel?

    @discardableResult
    func runModal() -> Response {
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 320, height: 0),
                            styleMask: [.titled, .fullSizeContentView],
                            backing: .buffered,
                            defer: false)
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = false
        panel.level = .modalPanel

        let content = makeContentView()
        panel.contentView = content
        panel.setContentSize(content.fittingSize)
        panel.center()
        self.panel = panel

        NSApp.runModal(for: panel)
        panel.orderOut(nil)
        self.panel = nil
        return response
    }

    private func makeContentView() -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 24, left: 24, bottom: 20, right: 24)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let iconView = NSImageView()
        iconView.image = icon ?? NSApp.applicationIconImage
        iconView.imageScaling = .scaleProportionallyUpOrDown
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 64),
            iconView.heightAnchor.constraint(equalToConstant: 64)
        ])
        stack.addArrangedSubview(iconView)
        stack.setCustomSpacing(14, after: iconView)

        let titleLabel = makeLabel(title, font: .boldSystemFont(ofSize: 14))
        stack.addArrangedSubview(titleLabel)

        let messageLabel = makeLabel(message, font: .systemFont(ofSize: 12))
        messageLabel.textColor = .secondaryLabelColor
        messageLabel.preferredMaxLayoutWidth = 260
        stack.addArrangedSubview(messageLabel)
        stack.setCustomSpacing(18, after: messageLabel)

        stack.addArrangedSubview(makeButton(title: primaryButton,
                                            action: #selector(primaryAction),
                                            isPrimary: true))

        if let secondaryTitle = secondaryButton {
            stack.addArrangedSubview(makeButton(title: secondaryTitle,
                                                action: #selector(secondaryAction),
                                                isPrimary: false))
        }

        let container = NSView()
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        ])
        return container
    }

    private func makeLabel(_ string: String, font: NSFont) -> NSTextField {
        let label = NSTextField(labelWithString: string)
        label.font = font
        label.alignment = .center
        label.lineBreakMode = .byWordWrapping
        label.maximumNumberOfLines = 0
        return label
    }

    private func makeButton(title: String, action: Selector, isPrimary: Bool) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .rounded
        button.keyEquivalent = isPrimary ? "\r" : "\u{1b}"
        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(equalToConstant: 240).isActive = true
        return button
    }

    @objc private func primaryAction() {
        response = .primary
        NSApp.stopModal()
    }

    @objc private func secondaryAction() {
        response = .secondary
        NSApp.stopModal()
    }
}
