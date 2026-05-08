//
//  PluginSecretVariableRow.swift
//  ActivateDock
//
//  Wrapper around two overlapping fields (NSSecureTextField + NSTextField)
//  with an eye toggle that swaps which one is visible. The active inner
//  field still emits NSTextFieldDelegate notifications and conforms to
//  PluginVariableEditing, so the existing settings delegate pipeline
//  doesn't need to know about the wrapper.
//

import Cocoa

final class PluginSecretVariableRow: NSView {

    private let secureField: PluginSecureVariableField
    private let plainField: PluginVariableField
    private let toggleButton = NSButton()
    private var revealed = false

    init(bundleId: String, varKey: String) {
        secureField = PluginSecureVariableField(bundleId: bundleId, varKey: varKey)
        plainField = PluginVariableField(bundleId: bundleId, varKey: varKey)
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        plainField.isHidden = true
        setupToggleButton()
        installSubviews()
    }
    required init?(coder: NSCoder) { nil }

    var stringValue: String {
        get { activeField.stringValue }
        set {
            secureField.stringValue = newValue
            plainField.stringValue = newValue
        }
    }

    var placeholderString: String? {
        get { activeField.placeholderString }
        set {
            secureField.placeholderString = newValue
            plainField.placeholderString = newValue
        }
    }

    var delegate: NSTextFieldDelegate? {
        get { activeField.delegate }
        set {
            secureField.delegate = newValue
            plainField.delegate = newValue
        }
    }

    private var activeField: NSTextField { revealed ? plainField : secureField }
    private var inactiveField: NSTextField { revealed ? secureField : plainField }

    private func setupToggleButton() {
        toggleButton.translatesAutoresizingMaskIntoConstraints = false
        toggleButton.bezelStyle = .accessoryBarAction
        toggleButton.isBordered = false
        toggleButton.target = self
        toggleButton.action = #selector(toggleVisibility)
        toggleButton.imageScaling = .scaleProportionallyDown
        toggleButton.toolTip = "Show / hide value"
        applyToggleImage()
    }

    private func applyToggleImage() {
        let symbol = revealed ? "eye.slash" : "eye"
        let cfg = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
        toggleButton.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?
            .withSymbolConfiguration(cfg)
        toggleButton.contentTintColor = .secondaryLabelColor
    }

    private func installSubviews() {
        addSubview(secureField)
        addSubview(plainField)
        addSubview(toggleButton)
        let common: [NSLayoutConstraint] = [
            secureField.topAnchor.constraint(equalTo: topAnchor),
            secureField.bottomAnchor.constraint(equalTo: bottomAnchor),
            secureField.leadingAnchor.constraint(equalTo: leadingAnchor),
            secureField.trailingAnchor.constraint(equalTo: toggleButton.leadingAnchor, constant: -6),

            plainField.topAnchor.constraint(equalTo: secureField.topAnchor),
            plainField.bottomAnchor.constraint(equalTo: secureField.bottomAnchor),
            plainField.leadingAnchor.constraint(equalTo: secureField.leadingAnchor),
            plainField.trailingAnchor.constraint(equalTo: secureField.trailingAnchor),

            toggleButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            toggleButton.trailingAnchor.constraint(equalTo: trailingAnchor),
            toggleButton.widthAnchor.constraint(equalToConstant: 22),
            toggleButton.heightAnchor.constraint(equalToConstant: 22),

            widthAnchor.constraint(greaterThanOrEqualToConstant: 240)
        ]
        NSLayoutConstraint.activate(common)
    }

    @objc private func toggleVisibility() {
        let pending = activeField.stringValue
        revealed.toggle()
        secureField.stringValue = pending
        plainField.stringValue = pending
        secureField.isHidden = revealed
        plainField.isHidden = !revealed
        applyToggleImage()
        window?.makeFirstResponder(activeField)
    }
}
