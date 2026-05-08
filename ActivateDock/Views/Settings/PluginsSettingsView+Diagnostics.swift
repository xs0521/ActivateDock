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
            stack.addArrangedSubview(makeDiagnosticRow(
                primary: "keyword \"\(conflict.keyword)\"",
                secondary: conflictDetail(conflict)
            ))
        }
        return stack
    }

    private func conflictDetail(_ c: PluginKeywordConflict) -> String {
        "kept \(c.keptBundleId); ignored \(c.droppedBundleIds.joined(separator: ", "))"
    }

    private func makeDiagnosticsHeader(failureCount: Int, conflictCount: Int) -> NSView {
        var parts: [String] = []
        if failureCount > 0 {
            parts.append("\(failureCount) plugin\(failureCount == 1 ? "" : "s") failed to load")
        }
        if conflictCount > 0 {
            parts.append("\(conflictCount) keyword conflict\(conflictCount == 1 ? "" : "s")")
        }
        let label = NSTextField(labelWithString: "Plugin issues — " + parts.joined(separator: ", "))
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
}
