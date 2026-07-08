//
//  StatusItemController.swift
//  ActivateDock
//

import Cocoa

final class StatusItemController {
    var onSettings: (() -> Void)?
    var onReportBug: (() -> Void)?
    var onCheckForUpdate: (() -> Void)?
    var onQuit: (() -> Void)?

    private let statusItem: NSStatusItem
    private let menu = NSMenu()

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        configureButton()
        rebuildMenu()
        statusItem.menu = menu
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

    private func configureButton() {
        guard let button = statusItem.button else { return }
        let image = NSImage(named: "StatusBarIcon")
        image?.isTemplate = true
        button.image = image
        button.toolTip = "ActivateDock"
    }

    @objc private func handleLocalizationChange() {
        rebuildMenu()
    }

    private func rebuildMenu() {
        menu.removeAllItems()

        let settingsItem = NSMenuItem(title: L("menu.settings"),
                                      action: #selector(handleSettings),
                                      keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let helpItem = NSMenuItem(title: L("menu.help"), action: nil, keyEquivalent: "")
        helpItem.submenu = makeHelpSubmenu()
        menu.addItem(helpItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: L("menu.quit"),
                                  action: #selector(handleQuit),
                                  keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    private func makeHelpSubmenu() -> NSMenu {
        let submenu = NSMenu()

        let reportItem = NSMenuItem(title: L("menu.report_bug"),
                                    action: #selector(handleReportBug),
                                    keyEquivalent: "")
        reportItem.target = self
        submenu.addItem(reportItem)

        let updateItem = NSMenuItem(title: L("menu.check_for_update"),
                                    action: #selector(handleCheckForUpdate),
                                    keyEquivalent: "")
        updateItem.target = self
        submenu.addItem(updateItem)

        return submenu
    }

    @objc private func handleSettings() {
        onSettings?()
    }

    @objc private func handleReportBug() {
        onReportBug?()
    }

    @objc private func handleCheckForUpdate() {
        onCheckForUpdate?()
    }

    @objc private func handleQuit() {
        if let onQuit {
            onQuit()
        } else {
            NSApp.terminate(nil)
        }
    }
}
