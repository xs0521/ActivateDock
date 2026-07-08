//
//  PluginsSettingsView+Import.swift
//  ActivateDock
//
//  Adds an "Import plugin" button to the plugins list. Spawns an open
//  panel for picking a .alfredworkflow / .zip file or a plugin
//  directory, then hands the chosen URL to PluginImporter and surfaces
//  the result via NSAlert. PluginWatcher's reload still drives the
//  Settings refresh; this file just brokers the user's intent.
//

import Cocoa
import UniformTypeIdentifiers

extension PluginsSettingsView {

    func makeImportRow() -> NSView {
        let button = NSButton()
        button.bezelStyle = .rounded
        button.title = L("plugins.import.button")
        button.target = self
        button.action = #selector(handleImportTapped)

        let hint = NSTextField(labelWithString: L("plugins.import.hint"))
        hint.font = .systemFont(ofSize: 11)
        hint.textColor = .secondaryLabelColor

        let row = NSStackView(views: [button, hint])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 10
        return row
    }

    @objc func handleImportTapped() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = L("plugins.import.panel_message")
        panel.prompt = L("plugins.import.panel_prompt")
        var types: [UTType] = [.zip, .folder]
        if let alfred = UTType(filenameExtension: "alfredworkflow") {
            types.insert(alfred, at: 0)
        }
        panel.allowedContentTypes = types

        let pick: (NSApplication.ModalResponse) -> Void = { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            self?.confirmImport(source: url) { confirmed in
                if confirmed {
                    self?.runImport(source: url, replaceExisting: false)
                }
            }
        }
        if let window {
            panel.beginSheetModal(for: window, completionHandler: pick)
        } else {
            pick(panel.runModal())
        }
    }

    private func runImport(source: URL, replaceExisting: Bool) {
        do {
            let result = try PluginImporter.install(from: source, replaceExisting: replaceExisting)
            WorkflowRegistry.shared.reload()
            presentInfo(
                title: L("plugins.import.success.title", result.displayName),
                detail: result.installedAt.path
            )
        } catch let error as PluginImporter.ImportError {
            if case .alreadyExists(let bundleId, _) = error {
                confirmReplace(bundleId: bundleId) { [weak self] confirmed in
                    if confirmed {
                        self?.runImport(source: source, replaceExisting: true)
                    }
                }
                return
            }
            presentError(error.errorDescription ?? error.localizedDescription)
        } catch {
            presentError(error.localizedDescription)
        }
    }

    private func confirmImport(source: URL, completion: @escaping (Bool) -> Void) {
        let alert = NSAlert()
        alert.messageText = L("plugins.import.confirm.title")
        alert.informativeText = L("plugins.import.confirm.body", source.lastPathComponent)
        alert.alertStyle = .warning
        alert.addButton(withTitle: L("plugins.import.confirm.import"))
        alert.addButton(withTitle: L("plugins.import.confirm.cancel"))
        let handler: (NSApplication.ModalResponse) -> Void = { resp in
            completion(resp == .alertFirstButtonReturn)
        }
        if let window {
            alert.beginSheetModal(for: window, completionHandler: handler)
        } else {
            handler(alert.runModal())
        }
    }

    private func confirmReplace(bundleId: String, completion: @escaping (Bool) -> Void) {
        let alert = NSAlert()
        alert.messageText = L("plugins.import.replace.title")
        alert.informativeText = L("plugins.import.replace.body", bundleId)
        alert.alertStyle = .warning
        alert.addButton(withTitle: L("plugins.import.replace.replace"))
        alert.addButton(withTitle: L("plugins.import.confirm.cancel"))
        let handler: (NSApplication.ModalResponse) -> Void = { resp in
            completion(resp == .alertFirstButtonReturn)
        }
        if let window {
            alert.beginSheetModal(for: window, completionHandler: handler)
        } else {
            handler(alert.runModal())
        }
    }

    private func presentInfo(title: String, detail: String) {
        presentAlert(title: title, detail: detail, style: .informational)
    }

    private func presentError(_ detail: String) {
        presentAlert(title: L("plugins.import.failure.title"), detail: detail, style: .warning)
    }

    private func presentAlert(title: String, detail: String, style: NSAlert.Style) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = detail
        alert.alertStyle = style
        alert.addButton(withTitle: L("plugins.import.ok"))
        if let window {
            alert.beginSheetModal(for: window, completionHandler: nil)
        } else {
            alert.runModal()
        }
    }
}
