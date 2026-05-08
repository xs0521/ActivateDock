//
//  SearchResultCell.swift
//  ActivateDock
//

import Cocoa

final class SearchResultCell: NSView {
    static let reuseIdentifier = NSUserInterfaceItemIdentifier("SearchResultCell")

    private let accentBar = NSView()
    private let iconView = NSImageView()
    private let spinner = NSProgressIndicator()
    private let textStack = NSStackView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let subtitleLabel = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }
    required init?(coder: NSCoder) { nil }

    private func setup() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        accentBar.translatesAutoresizingMaskIntoConstraints = false
        accentBar.wantsLayer = true
        accentBar.layer?.cornerRadius = 1.5
        accentBar.layer?.backgroundColor = NSColor.controlAccentColor.cgColor
        accentBar.isHidden = true
        addSubview(accentBar)

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.imageScaling = .scaleProportionallyUpOrDown
        addSubview(iconView)

        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.isDisplayedWhenStopped = false
        spinner.isHidden = true
        addSubview(spinner)

        titleLabel.font = .systemFont(ofSize: 14)
        titleLabel.textColor = .labelColor
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.maximumNumberOfLines = 1
        titleLabel.cell?.usesSingleLineMode = true

        subtitleLabel.font = .systemFont(ofSize: 11)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.lineBreakMode = .byTruncatingTail
        subtitleLabel.maximumNumberOfLines = 1
        subtitleLabel.cell?.usesSingleLineMode = true
        subtitleLabel.isHidden = true

        textStack.translatesAutoresizingMaskIntoConstraints = false
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 2
        textStack.distribution = .fill
        textStack.addArrangedSubview(titleLabel)
        textStack.addArrangedSubview(subtitleLabel)
        addSubview(textStack)

        NSLayoutConstraint.activate([
            accentBar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            accentBar.centerYAnchor.constraint(equalTo: centerYAnchor),
            accentBar.widthAnchor.constraint(equalToConstant: 4),
            accentBar.heightAnchor.constraint(equalToConstant: 18),

            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 32),
            iconView.heightAnchor.constraint(equalToConstant: 32),

            spinner.centerXAnchor.constraint(equalTo: iconView.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: iconView.centerYAnchor),

            textStack.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            textStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            textStack.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    func configure(with app: InstalledApp) {
        resetState()
        iconView.image = app.icon
        titleLabel.stringValue = app.displayName
    }

    func configure(alfredItem item: AlfredItem) {
        resetState()
        let isValid = item.valid != false
        iconView.image = Self.resolveAlfredIcon(item.icon?.path) ?? Self.fallbackAlfredIcon
        iconView.alphaValue = isValid ? 1.0 : 0.4
        titleLabel.stringValue = item.title
        titleLabel.textColor = isValid ? .labelColor : .tertiaryLabelColor
        let sub = item.subtitle ?? ""
        subtitleLabel.stringValue = sub
        subtitleLabel.isHidden = sub.isEmpty
    }

    func configureLoading() {
        resetState()
        spinner.isHidden = false
        spinner.startAnimation(nil)
        titleLabel.textColor = .secondaryLabelColor
        titleLabel.stringValue = "loading…"
    }

    func configureError(title: String, detail: String) {
        resetState()
        iconView.image = Self.errorIcon
        iconView.contentTintColor = .systemRed
        titleLabel.textColor = .systemRed
        titleLabel.stringValue = title
        let trimmed = detail.trimmingCharacters(in: .whitespacesAndNewlines)
        subtitleLabel.stringValue = trimmed
        subtitleLabel.isHidden = trimmed.isEmpty
    }

    private func resetState() {
        spinner.stopAnimation(nil)
        spinner.isHidden = true
        iconView.image = nil
        iconView.contentTintColor = nil
        iconView.alphaValue = 1.0
        titleLabel.textColor = .labelColor
        titleLabel.stringValue = ""
        subtitleLabel.stringValue = ""
        subtitleLabel.isHidden = true
    }

    func setSelected(_ selected: Bool) {
        accentBar.isHidden = !selected
    }

    private static func resolveAlfredIcon(_ path: String?) -> NSImage? {
        guard let p = path, !p.isEmpty else { return nil }
        return NSImage(contentsOfFile: p)
    }

    private static let fallbackAlfredIcon: NSImage = {
        let cfg = NSImage.SymbolConfiguration(pointSize: 20, weight: .regular)
        let img = NSImage(systemSymbolName: "globe", accessibilityDescription: nil)?
            .withSymbolConfiguration(cfg)
        return img ?? NSImage()
    }()

    private static let errorIcon: NSImage = {
        let cfg = NSImage.SymbolConfiguration(pointSize: 22, weight: .regular)
        let img = NSImage(systemSymbolName: "exclamationmark.triangle.fill",
                          accessibilityDescription: nil)?
            .withSymbolConfiguration(cfg)
        return img ?? NSImage()
    }()
}
