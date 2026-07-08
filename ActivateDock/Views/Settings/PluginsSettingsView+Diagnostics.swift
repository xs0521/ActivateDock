//
//  PluginsSettingsView+Diagnostics.swift
//  ActivateDock
//
//  Renders a "Plugin issues" banner above the per-plugin list when
//  WorkflowRegistry's most recent reload produced load failures or
//  keyword conflicts. Without this section those problems would only
//  show up in NSLog and the user would have no clue why a plugin
//  isn't responding to its keyword.
//

import Cocoa

extension PluginsSettingsView {

    func makeDiagnosticsSection() -> NSView? {
        let registry = WorkflowRegistry.shared
        let failures = registry.loadFailures
        let conflicts = registry.keywordConflicts
        if failures.isEmpty && conflicts.isEmpty { return nil }

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6

        stack.addArrangedSubview(makeDiagnosticsHeader(
            failureCount: failures.count,
            conflictCount: conflicts.count
        ))
        for failure in failures {
            stack.addArrangedSubview(makeDiagnosticRow(
                primary: failure.directoryName,
                secondary: failure.reason.displayMessage
            ))
        }
        for conflict in conflicts {
            stack.addArrangedSubview(makeConflictRow(conflict))
        }
        return stack
    }

    private func conflictDetail(_ c: PluginKeywordConflict) -> String {
        "kept \(c.keptBundleId); ignored \(c.droppedBundleIds.joined(separator: ", "))"
    }

    private func makeDiagnosticsHeader(failureCount: Int, conflictCount: Int) -> NSView {
        var parts: [String] = []
        if failureCount > 0 {
            let key = failureCount == 1 ? "plugins.diag.header.failures_one" : "plugins.diag.header.failures_other"
            parts.append(L(key, failureCount))
        }
        if conflictCount > 0 {
            let key = conflictCount == 1 ? "plugins.diag.header.conflicts_one" : "plugins.diag.header.conflicts_other"
            parts.append(L(key, conflictCount))
        }
        let label = NSTextField(labelWithString: L("plugins.diag.header.prefix") + parts.joined(separator: ", "))
        label.font = .boldSystemFont(ofSize: 12)
        label.textColor = .systemOrange
        return label
    }

    private func makeDiagnosticRow(primary: String, secondary: String) -> NSView {
        let primaryLabel = NSTextField(labelWithString: primary)
        primaryLabel.font = .systemFont(ofSize: 11, weight: .medium)
        primaryLabel.textColor = .labelColor

        let secondaryLabel = NSTextField(wrappingLabelWithString: secondary)
        secondaryLabel.font = .systemFont(ofSize: 11)
        secondaryLabel.textColor = .secondaryLabelColor
        secondaryLabel.preferredMaxLayoutWidth = 360

        let row = NSStackView(views: [primaryLabel, secondaryLabel])
        row.orientation = .horizontal
        row.alignment = .firstBaseline
        row.spacing = 8
        return row
    }

    private func makeConflictRow(_ conflict: PluginKeywordConflict) -> NSView {
        let label = NSTextField(labelWithString: L("plugins.diag.conflict.label", conflict.keyword))
        label.font = .systemFont(ofSize: 11, weight: .medium)
        label.textColor = .labelColor

        let popup = NSPopUpButton()
        popup.controlSize = .small
        popup.font = .systemFont(ofSize: 11)
        popup.addItems(withTitles: conflict.candidateBundleIds)
        popup.selectItem(withTitle: conflict.selectedBundleId)
        popup.identifier = NSUserInterfaceItemIdentifier(conflict.keyword)
        popup.target = self
        popup.action = #selector(handleKeywordConflictChoice(_:))

        let suffix = NSTextField(labelWithString: L("plugins.diag.conflict.suffix"))
        suffix.font = .systemFont(ofSize: 11)
        suffix.textColor = .secondaryLabelColor

        let row = NSStackView(views: [label, popup, suffix])
        row.orientation = .horizontal
        row.alignment = .firstBaseline
        row.spacing = 8
        return row
    }

    @objc private func handleKeywordConflictChoice(_ sender: NSPopUpButton) {
        guard let keyword = sender.identifier?.rawValue,
              let bundleId = sender.selectedItem?.title else { return }
        PluginConfigStore.shared.setPreferredKeywordOwner(bundleId, for: keyword)
        WorkflowRegistry.shared.reload()
    }
}
