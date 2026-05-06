//
//  AppDelegate.swift
//  ActivateDock
//
//  Created by luoshuai on 2026/5/5.
//

import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first?.makeKeyAndOrderFront(nil)

        HotKeyManager.shared.onTrigger = { [weak self] in
            self?.toggleLauncher()
        }
        HotKeyManager.shared.register()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showLauncher()
        return true
    }

    func applicationDidResignActive(_ notification: Notification) {
        NSApp.windows.first?.orderOut(nil)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        HotKeyManager.shared.unregister()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }

    private func toggleLauncher() {
        if let win = NSApp.windows.first, win.isVisible {
            win.orderOut(nil)
        } else {
            showLauncher()
        }
    }

    private func showLauncher() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first?.makeKeyAndOrderFront(nil)
    }
}
