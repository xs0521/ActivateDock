//
//  SettingsContentBuilder.swift
//  ActivateDock
//

import Cocoa

enum SettingsContentBuilder {
    static func build(recorder: KeyRecorderView,
                      accessibilitySwitch: StateSwitch,
                      fourFingerSwipeSwitch: StateSwitch,
                      languageControl: NSSegmentedControl,
                      pluginsView: PluginsSettingsView) -> NSView {
        let general = buildGeneralPage(
            recorder: recorder,
            accessibilitySwitch: accessibilitySwitch,
            fourFingerSwipeSwitch: fourFingerSwipeSwitch,
            languageControl: languageControl
        )
        let plugins = buildPluginsPage(pluginsView: pluginsView)
        return SettingsTabContainer(pages: [
            .init(title: L("settings.tab.general"), view: general),
            .init(title: L("settings.tab.plugins"), view: plugins)
        ])
    }

    private static func buildGeneralPage(recorder: KeyRecorderView,
                                         accessibilitySwitch: StateSwitch,
                                         fourFingerSwipeSwitch: StateSwitch,
                                         languageControl: NSSegmentedControl) -> NSView {
        let stack = makePageStack()
        stack.addArrangedSubview(makeSection(
            title: L("settings.section.shortcut.title"),
            subtitle: L("settings.section.shortcut.subtitle"),
            trailing: recorder
        ))
        stack.addArrangedSubview(makeDivider())
        stack.addArrangedSubview(makeSection(
            title: L("settings.section.accessibility.title"),
            subtitle: L("settings.section.accessibility.subtitle"),
            trailing: accessibilitySwitch
        ))
        stack.addArrangedSubview(makeDivider())
        stack.addArrangedSubview(makeSection(
            title: L("settings.section.four_finger_swipe.title"),
            subtitle: L("settings.section.four_finger_swipe.subtitle"),
            trailing: fourFingerSwipeSwitch
        ))
        stack.addArrangedSubview(makeDivider())
        stack.addArrangedSubview(makeSection(
            title: L("settings.section.language.title"),
            subtitle: L("settings.section.language.subtitle"),
            trailing: languageControl
        ))
        stack.addArrangedSubview(makeDivider())
        stack.addArrangedSubview(makeSection(
            title: L("settings.section.version.title"),
            subtitle: L("settings.section.version.subtitle"),
            trailing: makeValueLabel(appVersionText())
        ))
        return wrapInScroll(stack)
    }

    private static func buildPluginsPage(pluginsView: PluginsSettingsView) -> NSView {
        let stack = makePageStack()
        let header = makePluginsHeader()
        stack.addArrangedSubview(header)
        stack.addArrangedSubview(pluginsView)
        // Stretch both header and pluginsView to the full content width.
        // edgeInsets consume 24pt left + 24pt right = 48pt from stack.width.
        header.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -48).isActive = true
        pluginsView.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -48).isActive = true
        return wrapInScroll(stack)
    }

    private static func makePageStack() -> NSStackView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 18
        stack.edgeInsets = NSEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }

    private static func wrapInScroll(_ stack: NSStackView) -> NSView {
        let scroll = NSScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.autohidesScrollers = true
        scroll.drawsBackground = false
        scroll.borderType = .noBorder

        // Flipped clip view → y=0 sits at the top, so a stack shorter
        // than the viewport pins to the top instead of floating to the
        // bottom (NSView's default unflipped origin is bottom-left).
        let clip = FlippedClipView()
        clip.drawsBackground = false
        scroll.contentView = clip
        scroll.documentView = stack

        let container = NSView()
        container.addSubview(scroll)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: container.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.topAnchor.constraint(equalTo: clip.topAnchor),
            stack.leadingAnchor.constraint(equalTo: clip.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: clip.trailingAnchor),
            stack.widthAnchor.constraint(equalTo: clip.widthAnchor)
        ])
        return container
    }

    private final class FlippedClipView: NSClipView {
        override var isFlipped: Bool { true }
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

    private static func makeValueLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .secondaryLabelColor
        return label
    }

    private static func appVersionText() -> String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
    }

    private static func makePluginsHeader() -> NSView {
        let title = makeTitle(L("settings.plugins.header.title"))
        let subtitle = makeSubtitle(L("settings.plugins.header.subtitle"))
        let stack = NSStackView(views: [title, subtitle])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        return stack
    }

    private static func makeDivider() -> NSView {
        let line = NSBox()
        line.boxType = .separator
        line.translatesAutoresizingMaskIntoConstraints = false
        line.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return line
    }
}
