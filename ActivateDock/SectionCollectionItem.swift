//
//  SectionCollectionItem.swift
//  ActivateDock
//

import Cocoa

final class SectionCollectionItem: NSCollectionViewItem {
    static let identifier = NSUserInterfaceItemIdentifier("SectionCollectionItem")
    static let itemHeight: CGFloat = 116

    private let card = NSView()
    private let accentBar = NSView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let countLabel = NSTextField(labelWithString: "")
    private let iconsStack = NSStackView()
    private(set) var buttons: [AppIconButton] = []

    var onAppTapped: ((AppIconButton) -> Void)?

    override func loadView() {
        view = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false
        setupCard()
    }

    private func setupCard() {
        card.translatesAutoresizingMaskIntoConstraints = false
        card.wantsLayer = true
        card.layer?.cornerRadius = 14
        card.layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.04).cgColor

        accentBar.translatesAutoresizingMaskIntoConstraints = false
        accentBar.wantsLayer = true
        accentBar.layer?.cornerRadius = 1.5

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 11, weight: .semibold)
        titleLabel.textColor = .secondaryLabelColor
        titleLabel.lineBreakMode = .byTruncatingTail

        countLabel.translatesAutoresizingMaskIntoConstraints = false
        countLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        countLabel.textColor = .tertiaryLabelColor

        iconsStack.orientation = .horizontal
        iconsStack.alignment = .centerY
        iconsStack.spacing = 8
        iconsStack.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(accentBar)
        card.addSubview(titleLabel)
        card.addSubview(countLabel)
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

            titleLabel.leadingAnchor.constraint(equalTo: accentBar.trailingAnchor, constant: 12),
            titleLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),

            countLabel.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 8),
            countLabel.firstBaselineAnchor.constraint(equalTo: titleLabel.firstBaselineAnchor),
            countLabel.trailingAnchor.constraint(lessThanOrEqualTo: card.trailingAnchor, constant: -12),

            iconsStack.leadingAnchor.constraint(equalTo: accentBar.trailingAnchor, constant: 10),
            iconsStack.trailingAnchor.constraint(lessThanOrEqualTo: card.trailingAnchor, constant: -8),
            iconsStack.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            iconsStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -10)
        ])
    }

    func configure(with group: AppGroup) {
        for view in iconsStack.arrangedSubviews {
            iconsStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        buttons.removeAll()

        titleLabel.stringValue = group.title
        countLabel.stringValue = "\(group.items.count)"
        accentBar.layer?.backgroundColor = group.accentColor.cgColor

        for app in group.items {
            let button = AppIconButton(app: app)
            button.target = self
            button.action = #selector(handleButtonTap(_:))
            buttons.append(button)
            iconsStack.addArrangedSubview(button)
        }
    }

    @objc private func handleButtonTap(_ sender: AppIconButton) {
        onAppTapped?(sender)
    }
}
