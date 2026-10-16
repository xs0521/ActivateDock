import Cocoa

extension PluginsSettingsView {
    func makeDeleteButton(directory: URL) -> NSButton {
        let button = NSButton(title: L("plugins.delete.button"),
                              target: self, action: #selector(handleDeleteTapped(_:)))
        button.bezelStyle = .rounded
        button.controlSize = .small
        button.contentTintColor = .systemRed
        button.identifier = NSUserInterfaceItemIdentifier(directory.path)
        return button
    }

    @objc private func handleDeleteTapped(_ sender: NSButton) {
        guard let path = sender.identifier?.rawValue,
              let graph = WorkflowRegistry.shared.allGraphs.first(where: {
                  $0.pluginDirectory.path == path
              }) else { return }
        window?.makeFirstResponder(nil)

        let alert = NSAlert()
        alert.messageText = L("plugins.delete.confirm.title", graph.name)
        alert.informativeText = L("plugins.delete.confirm.body")
        alert.alertStyle = .warning
        alert.addButton(withTitle: L("plugins.delete.button"))
        alert.addButton(withTitle: L("plugins.import.confirm.cancel"))
        let handler: (NSApplication.ModalResponse) -> Void = { [weak self] response in
            guard response == .alertFirstButtonReturn else { return }
            do {
                try PluginRemover.remove(at: graph.pluginDirectory)
                PluginConfigStore.shared.removeOverrides(for: graph.bundleId)
                WorkflowRegistry.shared.reload()
            } catch {
                self?.presentDeleteError(error)
            }
        }
        if let window {
            alert.beginSheetModal(for: window, completionHandler: handler)
        } else {
            handler(alert.runModal())
        }
    }

    private func presentDeleteError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = L("plugins.delete.failure.title")
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.addButton(withTitle: L("plugins.import.ok"))
        if let window {
            alert.beginSheetModal(for: window, completionHandler: nil)
        } else {
            alert.runModal()
        }
    }
}
