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
        buildMenu()
        statusItem.menu = menu
    }

    private func configureButton() {
        guard let button = statusItem.button else { return }
        let image = NSImage(named: "StatusBarIcon")
        image?.isTemplate = true
        button.image = image
        button.toolTip = "ActivateDock"
    }

    private func buildMenu() {
        let settingsItem = NSMenuItem(title: "Settings…",
                                      action: #selector(handleSettings),
                                      keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let helpItem = NSMenuItem(title: "Help", action: nil, keyEquivalent: "")
        helpItem.submenu = makeHelpSubmenu()
        menu.addItem(helpItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit",
                                  action: #selector(handleQuit),
                                  keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    private func makeHelpSubmenu() -> NSMenu {
        let submenu = NSMenu()

        let reportItem = NSMenuItem(title: "Report Bug",
                                    action: #selector(handleReportBug),
                                    keyEquivalent: "")
        reportItem.target = self
        submenu.addItem(reportItem)

        let updateItem = NSMenuItem(title: "Check for Update…",
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
