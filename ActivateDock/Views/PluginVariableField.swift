//
//  PluginVariableField.swift
//  ActivateDock
//
//  NSTextField / NSSecureTextField subclasses that carry the
//  (bundleId, varKey) they edit, so a single delegate can route end-
//  editing back to PluginConfigStore. PluginVariableEditing is the
//  protocol the delegate uses without caring which subclass it has.
//

import Cocoa

protocol PluginVariableEditing: AnyObject {
    var bundleId: String { get }
    var varKey: String { get }
    var stringValue: String { get }
}

private func configureCommon(_ field: NSTextField) {
    field.translatesAutoresizingMaskIntoConstraints = false
    field.font = .systemFont(ofSize: 12)
    field.bezelStyle = .roundedBezel
    field.isBordered = true
    field.isEditable = true
    field.usesSingleLineMode = true
    field.lineBreakMode = .byTruncatingTail
}

final class PluginVariableField: NSTextField, PluginVariableEditing {
    let bundleId: String
    let varKey: String

    init(bundleId: String, varKey: String) {
        self.bundleId = bundleId
        self.varKey = varKey
        super.init(frame: .zero)
        configureCommon(self)
    }
    required init?(coder: NSCoder) { nil }
}

final class PluginSecureVariableField: NSSecureTextField, PluginVariableEditing {
    let bundleId: String
    let varKey: String

    init(bundleId: String, varKey: String) {
        self.bundleId = bundleId
        self.varKey = varKey
        super.init(frame: .zero)
        configureCommon(self)
    }
    required init?(coder: NSCoder) { nil }
}
