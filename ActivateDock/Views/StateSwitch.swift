//
//  StateSwitch.swift
//  ActivateDock
//

import Cocoa

final class StateSwitch: NSView {
    var onTap: (() -> Void)?

    var state: NSControl.StateValue {
        get { underlying.state }
        set { underlying.state = newValue }
    }

    private let underlying = NSSwitch()
    private let overlay = NSButton()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupViews()
    }

    required init?(coder: NSCoder) { fatalError() }

    convenience init() {
        self.init(frame: .zero)
    }

    override var intrinsicContentSize: NSSize {
        underlying.intrinsicContentSize
    }

    private func setupViews() {
        underlying.translatesAutoresizingMaskIntoConstraints = false
        addSubview(underlying)

        overlay.translatesAutoresizingMaskIntoConstraints = false
        overlay.title = ""
        overlay.isBordered = false
        overlay.isTransparent = true
        overlay.bezelStyle = .smallSquare
        overlay.target = self
        overlay.action = #selector(handleTap)
        addSubview(overlay)

        NSLayoutConstraint.activate([
            underlying.leadingAnchor.constraint(equalTo: leadingAnchor),
            underlying.trailingAnchor.constraint(equalTo: trailingAnchor),
            underlying.topAnchor.constraint(equalTo: topAnchor),
            underlying.bottomAnchor.constraint(equalTo: bottomAnchor),
            overlay.leadingAnchor.constraint(equalTo: leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: trailingAnchor),
            overlay.topAnchor.constraint(equalTo: topAnchor),
            overlay.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    @objc private func handleTap() {
        onTap?()
    }
}
