//
//  AppActivator.swift
//  ActivateDock
//

import Cocoa
import ApplicationServices

enum AppActivator {
    @discardableResult
    static func activate(_ app: NSRunningApplication) -> Bool {
        deminiaturizeWindows(pid: app.processIdentifier)
        if let bundleURL = app.bundleURL {
            NSWorkspace.shared.openApplication(
                at: bundleURL,
                configuration: NSWorkspace.OpenConfiguration(),
                completionHandler: nil
            )
            return true
        }
        return app.activate(options: [.activateAllWindows])
    }

    static func ensureAccessibilityPrompt() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    private static func deminiaturizeWindows(pid: pid_t) {
        let appElement = AXUIElementCreateApplication(pid)
        var windowsRef: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef)
        guard err == .success, let windows = windowsRef as? [AXUIElement] else { return }
        for window in windows {
            var minimized: CFTypeRef?
            AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &minimized)
            if let isMin = minimized as? Bool, isMin {
                AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, false as CFTypeRef)
            }
        }
    }
}
