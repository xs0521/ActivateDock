//
//  SettingsContentBuilder.swift
//  ActivateDock
//

import Cocoa

enum SettingsContentBuilder {
    static func build(recorder: KeyRecorderView,
                      accessibilitySwitch: StateSwitch) -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 18
        stack.edgeInsets = NSEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
        stack.translatesAutoresizingMaskIntoConstraints = false

        stack.addArrangedSubview(makeSection(
            title: "Activation Shortcut",
            subtitle: "Press a key combination to summon ActivateDock from anywhere.",
            trailing: recorder
        ))
        stack.addArrangedSubview(makeDivider())
        stack.addArrangedSubview(makeSection(
            title: "Accessibility Permission",
            subtitle: "Used to restore minimized windows when you click an app icon. App switching still works without this permission.",
            trailing: accessibilitySwitch
        ))

        let container = NSView()
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        ])
        return container
    }

    private static func makeSection(title: String, subtitle: String, trailing: NSView) -> NSView {
        let titleLabel = makeTitle(title)
        let subtitleLabel = makeSubtitle(subtitle)

        let titleRow = NSStackView(views: [titleLabel, NSView(), trailing])
        titleRow.orientation = .horizontal
        titleRow.alignment = .centerY
        titleRow.spacing = 12
        titleRow.distribution = .fill
        titleRow.translatesAutoresizingMaskIntoConstraints = false

        let section = NSStackView(views: [titleRow, subtitleLabel])
        section.orientation = .vertical
        section.alignment = .leading
        section.spacing = 6
        section.distribution = .fill

        titleRow.widthAnchor.constraint(equalTo: section.widthAnchor).isActive = true
        subtitleLabel.widthAnchor.constraint(equalTo: section.widthAnchor).isActive = true
        return section
    }

    private static func makeTitle(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .boldSystemFont(ofSize: 13)
        return label
    }

    private static func makeSubtitle(_ text: String) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: text)
        label.font = .systemFont(ofSize: 11)
        label.textColor = .secondaryLabelColor
        label.preferredMaxLayoutWidth = 360
        return label
    }

    private static func makeDivider() -> NSView {
        let line = NSBox()
        line.boxType = .separator
        line.translatesAutoresizingMaskIntoConstraints = false
        line.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return line
    }
}
