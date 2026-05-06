//
//  KeyRecorderView.swift
//  ActivateDock
//

import Carbon.HIToolbox
import Cocoa

final class KeyRecorderView: NSControl {
    var combo: HotKeyCombo {
        didSet { updateAppearance() }
    }
    var onChange: ((HotKeyCombo) -> Void)?

    private let label = NSTextField(labelWithString: "")
    private var localMonitor: Any?
    private var isRecording = false {
        didSet { updateAppearance() }
    }

    init(combo: HotKeyCombo) {
        self.combo = combo
        super.init(frame: .zero)
        setupView()
    }

    required init?(coder: NSCoder) { fatalError() }

    deinit {
        removeMonitor()
    }

    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    override func resignFirstResponder() -> Bool {
        if isRecording { stopRecording() }
        return super.resignFirstResponder()
    }

    private func setupView() {
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.cgColor
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        label.translatesAutoresizingMaskIntoConstraints = false
        label.alignment = .center
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.isSelectable = false
        addSubview(label)

        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -8),
            heightAnchor.constraint(equalToConstant: 28),
            widthAnchor.constraint(greaterThanOrEqualToConstant: 160)
        ])
        updateAppearance()
    }

    private func startRecording() {
        guard !isRecording else { return }
        window?.makeFirstResponder(self)
        isRecording = true
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self else { return event }
            return self.handleKeyDown(event) ? nil : event
        }
    }

    private func stopRecording() {
        removeMonitor()
        isRecording = false
        window?.makeFirstResponder(nil)
    }

    private func removeMonitor() {
        if let m = localMonitor {
            NSEvent.removeMonitor(m)
            localMonitor = nil
        }
    }

    private func handleKeyDown(_ event: NSEvent) -> Bool {
        if Int(event.keyCode) == kVK_Escape {
            stopRecording()
            return true
        }
        let cocoaMods = event.modifierFlags.intersection([.command, .option, .control, .shift])
        guard !cocoaMods.isEmpty else { return false }

        let newCombo = HotKeyCombo(
            keyCode: UInt32(event.keyCode),
            modifiers: HotKeyCombo.carbonFlags(from: cocoaMods),
            displayChar: HotKeyCombo.displayChar(for: event)
        )
        combo = newCombo
        stopRecording()
        onChange?(newCombo)
        return true
    }

    private func updateAppearance() {
        if isRecording {
            label.stringValue = "Press shortcut…"
            label.textColor = .secondaryLabelColor
            layer?.borderColor = NSColor.controlAccentColor.cgColor
        } else {
            label.stringValue = combo.displayString
            label.textColor = .labelColor
            layer?.borderColor = NSColor.separatorColor.cgColor
        }
    }
}
