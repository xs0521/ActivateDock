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
    private let languageControl = NSSegmentedControl()
    private var accessibilityTimer: Timer?
    private var hasPromptedAccessibility = false

    private convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 560),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.hidesOnDeactivate = false
        self.init(window: window)
        window.delegate = self
        configureLanguageControl()
        rebuildContent()
        wireActions()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleLocalizationChange),
            name: LocalizationManager.didChangeNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
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
        languageControl.target = self
        languageControl.action = #selector(handleLanguageChange(_:))
    }

    private func configureLanguageControl() {
        let cases = AppLanguage.allCases
        languageControl.segmentStyle = .texturedRounded
        languageControl.trackingMode = .selectOne
        languageControl.segmentCount = cases.count
        for (i, lang) in cases.enumerated() {
            languageControl.setLabel(lang.displayName, forSegment: i)
            languageControl.setWidth(72, forSegment: i)
        }
        syncLanguageControl()
    }

    private func syncLanguageControl() {
        let current = LocalizationManager.shared.currentLanguage
        if let idx = AppLanguage.allCases.firstIndex(of: current) {
            languageControl.selectedSegment = idx
        }
    }

    @objc private func handleLanguageChange(_ sender: NSSegmentedControl) {
        let cases = AppLanguage.allCases
        let idx = sender.selectedSegment
        guard cases.indices.contains(idx) else { return }
        LocalizationManager.shared.setLanguage(cases[idx])
    }

    @objc private func handleLocalizationChange() {
        rebuildContent()
        syncLanguageControl()
    }

    private func rebuildContent() {
        window?.title = L("settings.window.title")
        window?.contentView = SettingsContentBuilder.build(
            recorder: recorder,
            accessibilitySwitch: accessibilitySwitch,
            fourFingerSwipeSwitch: fourFingerSwipeSwitch,
            languageControl: languageControl,
            pluginsView: pluginsView
        )
        pluginsView.rebuild()
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
