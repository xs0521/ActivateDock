//
//  SectionCollectionItem.swift
//  ActivateDock
//

import Cocoa

final class DraggableSectionView: NSView {
    var onDragStart: ((NSPoint) -> Void)?
    var onDragMove: ((NSPoint) -> Void)?
    var onDragEnd: ((NSPoint) -> Void)?

    private var pressStart: NSPoint?
    private var isDragging = false
    private static let threshold: CGFloat = 4

    override func mouseDown(with event: NSEvent) {
        pressStart = event.locationInWindow
        isDragging = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = pressStart else { return }
        let p = event.locationInWindow
        if !isDragging {
            if abs(p.y - start.y) > Self.threshold || abs(p.x - start.x) > Self.threshold {
                isDragging = true
                onDragStart?(p)
            }
            return
        }
        onDragMove?(p)
    }

    override func mouseUp(with event: NSEvent) {
        if isDragging {
            onDragEnd?(event.locationInWindow)
        }
        pressStart = nil
        isDragging = false
    }
}

final class SectionCollectionItem: NSCollectionViewItem {
    static let identifier = NSUserInterfaceItemIdentifier("SectionCollectionItem")
    static let itemHeight: CGFloat = 92

    private let card = NSView()
    private let accentBar = NSView()
    private let iconsStack = NSStackView()
    private(set) var buttons: [AppIconButton] = []

    var onAppTapped: ((AppIconButton) -> Void)?
    var onDragStart: ((NSPoint) -> Void)?
    var onDragMove: ((NSPoint) -> Void)?
    var onDragEnd: ((NSPoint) -> Void)?
    var onIconDragStart: ((AppIconButton, NSPoint) -> Void)?
    var onIconDragMove: ((NSPoint) -> Void)?
    var onIconDragEnd: ((NSPoint) -> Void)?

    private var defaultCardBackground: CGColor {
        NSColor.labelColor.withAlphaComponent(0.24).cgColor
    }
    private var highlightedCardBackground: CGColor {
        NSColor.labelColor.withAlphaComponent(0.42).cgColor
    }

    override func loadView() {
        let v = DraggableSectionView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.onDragStart = { [weak self] p in self?.onDragStart?(p) }
        v.onDragMove = { [weak self] p in self?.onDragMove?(p) }
        v.onDragEnd = { [weak self] p in self?.onDragEnd?(p) }
        view = v
        setupCard()
    }

    private func setupCard() {
        card.translatesAutoresizingMaskIntoConstraints = false
        card.wantsLayer = true
        card.layer?.cornerRadius = 14
        card.layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.24).cgColor

        accentBar.translatesAutoresizingMaskIntoConstraints = false
        accentBar.wantsLayer = true
        accentBar.layer?.cornerRadius = 1.5

        iconsStack.orientation = .horizontal
        iconsStack.alignment = .centerY
        iconsStack.spacing = 8
        iconsStack.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(accentBar)
        card.addSubview(iconsStack)
        view.addSubview(card)

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: view.topAnchor),
            card.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            card.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            card.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            accentBar.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            accentBar.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            accentBar.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
            accentBar.widthAnchor.constraint(equalToConstant: 3),

            iconsStack.leadingAnchor.constraint(equalTo: accentBar.trailingAnchor, constant: 12),
            iconsStack.trailingAnchor.constraint(lessThanOrEqualTo: card.trailingAnchor, constant: -10),
            iconsStack.centerYAnchor.constraint(equalTo: card.centerYAnchor)
        ])
    }

    func configure(with group: AppGroup) {
        for view in iconsStack.arrangedSubviews {
            iconsStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        buttons.removeAll()

        accentBar.layer?.backgroundColor = group.accentColor.cgColor

        for app in group.items {
            let button = AppIconButton(app: app)
            button.target = self
            button.action = #selector(handleButtonTap(_:))
            button.onDragStart = { [weak self, weak button] p in
                guard let button = button else { return }
                self?.onIconDragStart?(button, p)
            }
            button.onDragMove = { [weak self] p in self?.onIconDragMove?(p) }
            button.onDragEnd = { [weak self] p in self?.onIconDragEnd?(p) }
            buttons.append(button)
            iconsStack.addArrangedSubview(button)
        }

        setDropHighlight(false)
    }

    func setDropHighlight(_ active: Bool) {
        CATransaction.begin()
        CATransaction.setAnimationDuration(0.18)
        CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(name: .easeOut))
        card.layer?.backgroundColor = active ? highlightedCardBackground : defaultCardBackground
        CATransaction.commit()
    }

    @objc private func handleButtonTap(_ sender: AppIconButton) {
        onAppTapped?(sender)
    }
}
