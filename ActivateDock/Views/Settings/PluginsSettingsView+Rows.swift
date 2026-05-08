//
//  PluginsSettingsView+Rows.swift
//  ActivateDock
//
//  Per-variable row builder extracted from PluginsSettingsView. Picks
//  a plain field or a secure-with-eye-toggle wrapper depending on
//  whether the variable name reads like a credential.
//

import Cocoa

extension PluginsSettingsView {

    func makeVariableRow(bundleId: String, varKey: String, placeholder: String) -> NSView {
        let label = NSTextField(labelWithString: varKey)
        label.font = .systemFont(ofSize: 12)
        label.alignment = .right
        label.translatesAutoresizingMaskIntoConstraints = false
        label.widthAnchor.constraint(equalToConstant: 90).isActive = true

        let stored = PluginConfigStore.shared.override(for: bundleId, varKey: varKey) ?? ""
        let field: NSView = makeField(bundleId: bundleId, varKey: varKey,
                                      placeholder: placeholder, stored: stored)

        let row = NSStackView(views: [label, field])
        row.orientation = .horizontal
        row.alignment = .firstBaseline
        row.spacing = 8
        return row
    }

    private func makeField(bundleId: String, varKey: String,
                           placeholder: String, stored: String) -> NSView {
        if PluginVariableSensitivity.isSecret(bundleId: bundleId, varKey: varKey) {
            let wrapper = PluginSecretVariableRow(bundleId: bundleId, varKey: varKey)
            wrapper.placeholderString = placeholder
            wrapper.stringValue = stored
            wrapper.delegate = self
            return wrapper
        }
        let plain = PluginVariableField(bundleId: bundleId, varKey: varKey)
        plain.placeholderString = placeholder
        plain.stringValue = stored
        plain.delegate = self
        plain.widthAnchor.constraint(greaterThanOrEqualToConstant: 240).isActive = true
        return plain
    }
}
