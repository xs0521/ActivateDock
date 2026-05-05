//
//  SectionCollectionItem.swift
//  ActivateDock
//

import Cocoa

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
            wireButton(button)
            buttons.append(button)
            iconsStack.addArrangedSubview(button)
        }

        setDropHighlight(false)
    }

    private func wireButton(_ button: AppIconButton) {
        button.target = self
        button.action = #selector(handleButtonTap(_:))
        button.onDragStart = { [weak self, weak button] p in
            guard let button = button else { return }
            self?.onIconDragStart?(button, p)
        }
        button.onDragMove = { [weak self] p in self?.onIconDragMove?(p) }
        button.onDragEnd = { [weak self] p in self?.onIconDragEnd?(p) }
    }

    func detachButton(at index: Int) -> AppIconButton? {
        guard buttons.indices.contains(index) else { return nil }
        let button = buttons.remove(at: index)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.22
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            ctx.allowsImplicitAnimation = true
            iconsStack.removeArrangedSubview(button)
            button.removeFromSuperview()
            iconsStack.layoutSubtreeIfNeeded()
        }
        return button
    }

    func attachButton(_ button: AppIconButton, at index: Int) {
        wireButton(button)
        let safe = max(0, min(index, buttons.count))
        buttons.insert(button, at: safe)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.22
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            ctx.allowsImplicitAnimation = true
            iconsStack.insertArrangedSubview(button, at: safe)
            iconsStack.layoutSubtreeIfNeeded()
        }
    }

    func moveButton(from old: Int, to new: Int) {
        guard buttons.indices.contains(old) else { return }
        let clamped = max(0, min(new, buttons.count - 1))
        guard old != clamped else { return }

        let button = buttons.remove(at: old)
        buttons.insert(button, at: clamped)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.22
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            ctx.allowsImplicitAnimation = true
            iconsStack.removeArrangedSubview(button)
            iconsStack.insertArrangedSubview(button, at: clamped)
            iconsStack.layoutSubtreeIfNeeded()
        }
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
