//
//  PluginsSettingsView.swift
//  ActivateDock
//
//  Renders one section per installed plugin with editable text fields
//  for each manifest variable. Saves overrides to PluginConfigStore on
//  field end-editing. Pulls plugin list from WorkflowRegistry, deduped
//  by bundleId.
//

import Cocoa

final class PluginsSettingsView: NSView, NSTextFieldDelegate {

    private let store = PluginConfigStore.shared
    private let stack = NSStackView()

    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        setupStack()
        rebuild()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRegistryReload),
            name: WorkflowRegistry.didReloadNotification,
            object: nil
        )
    }
    required init?(coder: NSCoder) { nil }

    deinit { NotificationCenter.default.removeObserver(self) }

    @objc private func handleRegistryReload() { rebuild() }

    private func setupStack() {
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 16
        stack.distribution = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor)
        ])
    }

    func rebuild() {
        for view in stack.arrangedSubviews { view.removeFromSuperview() }

        if let diagnostics = makeDiagnosticsSection() {
            stack.addArrangedSubview(diagnostics)
            stack.addArrangedSubview(makeDivider())
        }

        stack.addArrangedSubview(makeImportRow())
        stack.addArrangedSubview(makeDivider())

        let groups = pluginGroups()
        if groups.isEmpty {
            stack.addArrangedSubview(makeMutedLabel("还没有插件,点上方按钮导入一个 .alfredworkflow / .zip 或插件目录。"))
            return
        }
        for (i, group) in groups.enumerated() {
            if i > 0 { stack.addArrangedSubview(makeDivider()) }
            stack.addArrangedSubview(makePluginGroup(group))
        }
    }

    private struct PluginGroup {
        let bundleId: String
        let name: String
        let description: String?
        let keywords: [String]
        let variables: [String: String]
    }

    private func pluginGroups() -> [PluginGroup] {
        WorkflowRegistry.shared.allGraphs.map { graph in
            PluginGroup(
                bundleId: graph.bundleId,
                name: graph.name,
                description: graph.description,
                keywords: graph.entrypoints.map(\.keyword).sorted(),
                variables: graph.variables
            )
        }
    }

    private func makePluginGroup(_ group: PluginGroup) -> NSView {
        let header = NSStackView()
        header.orientation = .horizontal
        header.alignment = .firstBaseline
        header.spacing = 8

        let title = NSTextField(labelWithString: group.name)
        title.font = .boldSystemFont(ofSize: 13)
        let kw = NSTextField(labelWithString: "keyword: " + group.keywords.joined(separator: ", "))
        kw.font = .systemFont(ofSize: 11)
        kw.textColor = .secondaryLabelColor
        header.addArrangedSubview(title)
        header.addArrangedSubview(kw)

        let body = NSStackView()
        body.orientation = .vertical
        body.alignment = .leading
        body.spacing = 6

        if let desc = group.description, !desc.isEmpty {
            body.addArrangedSubview(makeMutedLabel(desc))
        }

        if group.variables.isEmpty {
            body.addArrangedSubview(makeMutedLabel("This plugin declares no configurable variables."))
        } else {
            for key in group.variables.keys.sorted() {
                body.addArrangedSubview(makeVariableRow(
                    bundleId: group.bundleId,
                    varKey: key,
                    placeholder: group.variables[key] ?? ""
                ))
            }
        }

        let outer = NSStackView()
        outer.orientation = .vertical
        outer.alignment = .leading
        outer.spacing = 8
        outer.addArrangedSubview(header)
        outer.addArrangedSubview(body)
        return outer
    }

    private func makeMutedLabel(_ text: String) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: text)
        label.font = .systemFont(ofSize: 11)
        label.textColor = .secondaryLabelColor
        label.preferredMaxLayoutWidth = 360
        return label
    }

    private func makeDivider() -> NSView {
        let line = NSBox()
        line.boxType = .separator
        line.translatesAutoresizingMaskIntoConstraints = false
        line.heightAnchor.constraint(equalToConstant: 1).isActive = true
        line.widthAnchor.constraint(greaterThanOrEqualToConstant: 360).isActive = true
        return line
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        guard let f = obj.object as? PluginVariableEditing else { return }
        store.setOverride(f.stringValue, for: f.bundleId, varKey: f.varKey)
    }
}
