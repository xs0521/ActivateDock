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
        button.title = "+ 导入插件"
        button.target = self
        button.action = #selector(handleImportTapped)

        let hint = NSTextField(labelWithString: ".alfredworkflow / .zip / 插件目录")
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
        panel.message = "选择 .alfredworkflow / .zip 文件或一个插件目录"
        panel.prompt = "导入"
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
                title: "已导入 \(result.displayName)",
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
        alert.messageText = "确认导入插件?"
        alert.informativeText = """
        插件可能包含会在搜索或执行动作时运行的脚本。请只导入你信任来源的插件。

        \(source.lastPathComponent)
        """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "导入")
        alert.addButton(withTitle: "取消")
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
        alert.messageText = "已存在同名插件"
        alert.informativeText = "插件 \"\(bundleId)\" 已经安装。继续会删除旧版本所有文件,然后装上新版本。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "替换")
        alert.addButton(withTitle: "取消")
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
        presentAlert(title: "导入失败", detail: detail, style: .warning)
    }

    private func presentAlert(title: String, detail: String, style: NSAlert.Style) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = detail
        alert.alertStyle = style
        alert.addButton(withTitle: "好")
        if let window {
            alert.beginSheetModal(for: window, completionHandler: nil)
        } else {
            alert.runModal()
        }
    }
}
