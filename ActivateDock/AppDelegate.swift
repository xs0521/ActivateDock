//
//  AppDelegate.swift
//  ActivateDock
//
//  Created by luoshuai on 2026/5/5.
//

import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    private var optionFlagsMonitor: Any?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first?.makeKeyAndOrderFront(nil)

        HotKeyManager.shared.onTrigger = { [weak self] in
            self?.showAndWatchOption()
        }
        HotKeyManager.shared.register()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showLauncher()
        return true
    }

    func applicationDidResignActive(_ notification: Notification) {
        hideLauncher()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        HotKeyManager.shared.unregister()
        stopWatchingOptionRelease()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }

    private func showAndWatchOption() {
        showLauncher()
        startWatchingOptionRelease()
    }

    private func showLauncher() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first?.makeKeyAndOrderFront(nil)
    }

    private func hideLauncher() {
        stopWatchingOptionRelease()
        NSApp.windows.first?.orderOut(nil)
    }

    private func startWatchingOptionRelease() {
        stopWatchingOptionRelease()
        if !NSEvent.modifierFlags.contains(.option) {
            DispatchQueue.main.async { [weak self] in self?.hideLauncher() }
            return
        }
        optionFlagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            if !event.modifierFlags.contains(.option) {
                self?.hideLauncher()
            }
            return event
        }
    }

    private func stopWatchingOptionRelease() {
        if let m = optionFlagsMonitor {
            NSEvent.removeMonitor(m)
            optionFlagsMonitor = nil
        }
    }
}
