//
//  AppDelegate.swift
//  ActivateDock
//
//

import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItemController: StatusItemController?
    private var pluginWatcher: PluginWatcher?
    private weak var launcherWindow: NSWindow?

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        PluginPaths.ensureExists()
        WorkflowRegistry.shared.reload()
        startPluginWatcher()

        NSApp.setActivationPolicy(.accessory)
        NSApp.activate(ignoringOtherApps: true)
        launcherWindow = NSApp.windows.first
        launcherWindow?.makeKeyAndOrderFront(nil)

        HotKeyManager.shared.onTrigger = { [weak self] in
            self?.toggleLauncher()
        }
        HotKeyManager.shared.register()
        FourFingerSwipeMonitor.shared.onSwipeDown = { [weak self] in
            self?.showLauncher()
        }
        FourFingerSwipeMonitor.shared.startIfEnabled()

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
        FourFingerSwipeMonitor.shared.stop()
        pluginWatcher?.stop()
    }

    private func startPluginWatcher() {
        let watcher = PluginWatcher {
            WorkflowRegistry.shared.reload()
        }
        watcher.start(at: PluginPaths.root.path)
        pluginWatcher = watcher
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
                alert.title = L("update.uptodate.title")
                alert.message = L("update.uptodate.body", current)
                alert.primaryButton = L("button.ok")
                alert.runModal()

            case .available(let latest, let current, let url):
                alert.title = L("update.available.title")
                alert.message = L("update.available.body", latest, current)
                alert.primaryButton = L("button.download")
                alert.secondaryButton = L("button.later")
                if alert.runModal() == .primary {
                    NSWorkspace.shared.open(url)
                }

            case .noReleaseYet:
                alert.title = L("update.no_release.title")
                alert.message = L("update.no_release.body")
                alert.primaryButton = L("button.open_releases")
                alert.secondaryButton = L("button.ok")
                if alert.runModal() == .primary {
                    NSWorkspace.shared.open(releasesURL)
                }

            case .rateLimited:
                alert.title = L("update.rate_limited.title")
                alert.message = L("update.rate_limited.body")
                alert.primaryButton = L("button.open_releases")
                alert.secondaryButton = L("button.ok")
                if alert.runModal() == .primary {
                    NSWorkspace.shared.open(releasesURL)
                }

            case .failed(let error):
                alert.title = L("update.failed.title")
                alert.message = error.localizedDescription
                alert.primaryButton = L("button.open_releases")
                alert.secondaryButton = L("button.ok")
                if alert.runModal() == .primary {
                    NSWorkspace.shared.open(releasesURL)
                }
            }
        }
    }
}
