//
//  SettingsWindowController.swift
//  ActivateDock
//

import Cocoa
import ApplicationServices

final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    static let shared = SettingsWindowController()

    private let recorder = KeyRecorderView(combo: HotKeyManager.shared.currentCombo)
    private let accessibilitySwitch = StateSwitch()
    private let fourFingerSwipeSwitch = StateSwitch()
    private let pluginsView = PluginsSettingsView()
    private var accessibilityTimer: Timer?
    private var hasPromptedAccessibility = false

    private convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 560),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "ActivateDock Settings"
        window.isReleasedWhenClosed = false
        window.hidesOnDeactivate = false
        self.init(window: window)
        window.delegate = self
        window.contentView = SettingsContentBuilder.build(
            recorder: recorder,
            accessibilitySwitch: accessibilitySwitch,
            fourFingerSwipeSwitch: fourFingerSwipeSwitch,
            pluginsView: pluginsView
        )
        wireActions()
    }

    func showAndActivate() {
        recorder.combo = HotKeyManager.shared.currentCombo
        pluginsView.rebuild()
        refreshAccessibility()
        refreshFourFingerSwipe()
        startAccessibilityWatch()

        NSApp.activate(ignoringOtherApps: true)
        if let win = window {
            if !win.isVisible { win.center() }
            win.makeKeyAndOrderFront(nil)
            win.orderFrontRegardless()
        }
    }

    func windowWillClose(_ notification: Notification) {
        stopAccessibilityWatch()
    }

    private func wireActions() {
        recorder.onChange = { combo in
            combo.save()
            HotKeyManager.shared.register(combo: combo)
        }
        accessibilitySwitch.onTap = { [weak self] in
            self?.accessibilitySwitchToggled()
        }
        fourFingerSwipeSwitch.onTap = { [weak self] in
            self?.fourFingerSwipeSwitchToggled()
        }
    }

    private func accessibilitySwitchToggled() {
        if isAccessibilityTrusted() {
            openAccessibilitySettings()
        } else if !hasPromptedAccessibility {
            hasPromptedAccessibility = true
            requestAccessibility()
        }
        refreshAccessibility()
    }

    private func refreshAccessibility() {
        let granted = isAccessibilityTrusted()
        if granted { hasPromptedAccessibility = false }
        accessibilitySwitch.state = granted ? .on : .off
    }

    private func fourFingerSwipeSwitchToggled() {
        let enabled = fourFingerSwipeSwitch.state != .on
        FourFingerSwipeMonitor.shared.setEnabled(enabled)
        refreshFourFingerSwipe()
    }

    private func refreshFourFingerSwipe() {
        fourFingerSwipeSwitch.state = FourFingerSwipePreferences.isEnabled ? .on : .off
    }

    private func startAccessibilityWatch() {
        stopAccessibilityWatch()
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.refreshAccessibility()
        }
        RunLoop.main.add(timer, forMode: .common)
        accessibilityTimer = timer
    }

    private func stopAccessibilityWatch() {
        accessibilityTimer?.invalidate()
        accessibilityTimer = nil
    }

    private func isAccessibilityTrusted() -> Bool {
        AXIsProcessTrusted()
    }

    private func requestAccessibility() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    private func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }
}
