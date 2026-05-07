//
//  ViewController+SearchHint.swift
//  ActivateDock
//

import Cocoa

extension ViewController: NSWindowDelegate {
    func setupSearchHint() {
        searchHintLabel.translatesAutoresizingMaskIntoConstraints = false
        searchHintLabel.font = searchField.font
        searchHintLabel.textColor = .placeholderTextColor
        searchHintLabel.backgroundColor = .clear
        searchHintLabel.drawsBackground = false
        searchHintLabel.isBezeled = false
        searchHintLabel.isEditable = false
        searchHintLabel.isSelectable = false
        searchHintLabel.lineBreakMode = .byTruncatingTail
        searchHintLabel.isHidden = true

        searchFieldBox.addSubview(searchHintLabel)

        let leading = searchHintLabel.leadingAnchor.constraint(
            equalTo: searchField.leadingAnchor, constant: 0
        )
        searchHintLeadingConstraint = leading

        NSLayoutConstraint.activate([
            leading,
            searchHintLabel.firstBaselineAnchor.constraint(equalTo: searchField.firstBaselineAnchor),
            searchHintLabel.trailingAnchor.constraint(
                lessThanOrEqualTo: searchClearButton.leadingAnchor, constant: -4
            )
        ])

        searchFieldEditor.onCompositionChange = { [weak self] in
            guard let self else { return }
            self.updateSearchHint(for: self.searchField.stringValue)
        }
    }

    func updateSearchHint(for text: String) {
        if searchFieldEditor.hasMarkedText() {
            searchHintLabel.isHidden = true
            return
        }
        guard let hint = SearchCommand.hint(for: text) ?? Self.pluginHint(for: text) else {
            searchHintLabel.isHidden = true
            return
        }
        let font = searchField.font ?? .systemFont(ofSize: 22)
        let width = (text as NSString).size(withAttributes: [.font: font]).width
        searchHintLeadingConstraint?.constant = ceil(width)
        searchHintLabel.stringValue = hint
        searchHintLabel.isHidden = false
    }

    private static func pluginHint(for text: String) -> String? {
        guard let space = text.firstIndex(of: " ") else { return nil }
        let suffix = text[text.index(after: space)...]
        guard suffix.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        let keyword = String(text[..<space])
        guard WorkflowRegistry.shared.workflow(forKeyword: keyword) != nil else { return nil }
        return "输入查询内容"
    }

    func windowWillReturnFieldEditor(_ sender: NSWindow, to client: Any?) -> Any? {
        if let cell = client as? NSCell, cell.controlView === searchField {
            return searchFieldEditor
        }
        if let view = client as? NSView, view === searchField {
            return searchFieldEditor
        }
        return nil
    }
}
