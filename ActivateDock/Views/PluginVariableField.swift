//
//  PluginVariableField.swift
//  ActivateDock
//
//  NSTextField subclass that carries the (bundleId, varKey) it edits, so
//  a single delegate can route end-editing back to PluginConfigStore.
//

import Cocoa

final class PluginVariableField: NSTextField {
    let bundleId: String
    let varKey: String

    init(bundleId: String, varKey: String) {
        self.bundleId = bundleId
        self.varKey = varKey
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        font = .systemFont(ofSize: 12)
        bezelStyle = .roundedBezel
        isBordered = true
        isEditable = true
        usesSingleLineMode = true
        lineBreakMode = .byTruncatingTail
    }
    required init?(coder: NSCoder) { nil }
}
