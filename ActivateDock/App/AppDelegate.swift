//
//  AppDelegate.swift
//  ActivateDock
//
//

import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItemController: StatusItemController?
    private weak var launcherWindow: NSWindow?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        PluginPaths.ensureExists()
        WorkflowRegistry.shared.reload()

        NSApp.setActivationPolicy(.accessory)
        NSApp.activate(ignoringOtherApps: true)
        launcherWindow = NSApp.windows.first
        launcherWindow?.makeKeyAndOrderFront(nil)

        HotKeyManager.shared.onTrigger = { [weak self] in
            self?.toggleLauncher()
        }
        HotKeyManager.shared.register()

        let controller = StatusItemController()
        controller.onSettings = { SettingsWindowController.shared.showAndActivate() }
        controller.onReportBug = { [weak self] in self?.openIssuesPage() }
        controller.onCheckForUpdate = { [weak self] in self?.checkForUpdate() }
        statusItemController = controller
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showLauncher()
        return true
    }

    func applicationDidResignActive(_ notification: Notification) {
        launcherWindow?.orderOut(nil)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        HotKeyManager.shared.unregister()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }

    private func toggleLauncher() {
        guard let win = launcherWindow else { return }
        if win.isVisible {
            win.orderOut(nil)
        } else {
            showLauncher()
        }
    }

    private func showLauncher() {
        NSApp.activate(ignoringOtherApps: true)
        launcherWindow?.makeKeyAndOrderFront(nil)
    }

    private func openIssuesPage() {
        guard let url = URL(string: "https://github.com/xs0521/ActivateDock/issues") else { return }
        NSWorkspace.shared.open(url)
    }

    private func checkForUpdate() {
        UpdateChecker.shared.check { result in
            NSApp.activate(ignoringOtherApps: true)
            let alert = CenteredAlertWindow()
            let releasesURL = UpdateChecker.shared.releasesPageURL

            switch result {
            case .upToDate(let current):
                alert.title = "You're up to date"
                alert.message = "ActivateDock \(current) is the latest version."
                alert.primaryButton = "OK"
                alert.runModal()

            case .available(let latest, let current, let url):
                alert.title = "New Version Available"
                alert.message = "ActivateDock \(latest) is available — you have \(current)."
                alert.primaryButton = "Download"
                alert.secondaryButton = "Later"
                if alert.runModal() == .primary {
                    NSWorkspace.shared.open(url)
                }

            case .noReleaseYet:
                alert.title = "No Releases Yet"
                alert.message = "ActivateDock hasn't published any GitHub releases yet."
                alert.primaryButton = "Open Releases Page"
                alert.secondaryButton = "OK"
                if alert.runModal() == .primary {
                    NSWorkspace.shared.open(releasesURL)
                }

            case .rateLimited:
                alert.title = "GitHub Rate Limit Reached"
                alert.message = "Too many update checks in a short period. Please try again in about an hour, or open the releases page manually."
                alert.primaryButton = "Open Releases Page"
                alert.secondaryButton = "OK"
                if alert.runModal() == .primary {
                    NSWorkspace.shared.open(releasesURL)
                }

            case .failed(let error):
                alert.title = "Update Check Failed"
                alert.message = error.localizedDescription
                alert.primaryButton = "Open Releases Page"
                alert.secondaryButton = "OK"
                if alert.runModal() == .primary {
                    NSWorkspace.shared.open(releasesURL)
                }
            }
        }
    }
}
