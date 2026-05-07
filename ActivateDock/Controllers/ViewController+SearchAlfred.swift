//
//  ViewController+SearchAlfred.swift
//  ActivateDock
//
//  Alfred plugin execution path. Hands the entry node to WorkflowExecutor
//  and translates UIIntent values into table-view updates. The executor
//  manages cancellation and the process lifecycle; this layer only deals
//  with UI state.
//

import Cocoa

extension ViewController {

    func runAlfred(graph: WorkflowGraph,
                   entrypoint: WorkflowGraph.Entrypoint,
                   query: String) {
        guard let node = graph.nodes[entrypoint.nodeUID] else {
            let msg = "entry node \(entrypoint.nodeUID) not found"
            searchResults = [.error(title: "\(graph.name) · 内部错误", detail: msg)]
            searchResultsTable.reloadData()
            return
        }
        let vars = PluginConfigStore.shared.mergedVariables(for: graph)
        executor.enter(graph: graph, entry: node, query: query, variables: vars) { [weak self] intent in
            self?.handleUIIntent(intent, graphName: graph.name)
        }
    }

    private func handleUIIntent(_ intent: UIIntent, graphName: String) {
        switch intent {
        case .showLoading:
            searchResults = [.loading]
            searchResultsTable.reloadData()
            searchResultsTable.deselectAll(nil)

        case .showItems(let items):
            searchResults = items.map(SearchRow.alfred)
            searchResultsTable.reloadData()
            if !searchResults.isEmpty {
                searchResultsTable.selectRowIndexes([0], byExtendingSelection: false)
                searchResultsTable.scrollRowToVisible(0)
            }

        case .showError(let err):
            let (title, detail) = Self.errorPresentation(for: err, graphName: graphName)
            searchResults = [.error(title: title, detail: detail)]
            searchResultsTable.reloadData()

        case .dismissAndPerform:
            searchField.stringValue = ""
            updateForSearchText("")
            view.window?.orderOut(nil)
        }
    }

    private static func errorPresentation(for err: WorkflowError,
                                          graphName: String) -> (title: String, detail: String) {
        switch err.kind {
        case .launchFailed(let e):
            return ("\(graphName) · 启动失败", e.localizedDescription)
        case .nodeFailed(let stderr, let code):
            if let hint = permissionHint(stderr: stderr) {
                return ("\(graphName) · 需要权限", hint)
            }
            let firstLine = stderr.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
            let trimmed = firstLine.trimmingCharacters(in: .whitespaces)
            let detail = trimmed.isEmpty ? "exit code \(code)" : "exit \(code): \(trimmed.prefix(180))"
            return ("\(graphName) · 运行错误", detail)
        case .decodeFailed(let raw, _):
            let snippet = raw.trimmingCharacters(in: .whitespacesAndNewlines).prefix(180)
            return ("\(graphName) · 输出解析失败", String(snippet))
        case .missingNode(let uid):
            return ("\(graphName) · 内部错误", "找不到节点 \(uid)")
        case .unsupportedNodeType(let type):
            return ("\(graphName) · 不支持的节点类型", type)
        }
    }

    private static func permissionHint(stderr: String) -> String? {
        let lower = stderr.lowercased()
        if lower.contains("authorization denied") ||
           lower.contains("operation not permitted") {
            return "系统设置 → 隐私与安全性 → 完全磁盘访问权限 → 添加 ActivateDock,然后重试。"
        }
        if lower.contains("not authorized to send apple events") ||
           lower.contains("not allowed to send apple events") ||
           lower.contains("error: -1743") ||
           lower.contains("(-1743)") {
            return "系统设置 → 隐私与安全性 → 自动化 → 给 ActivateDock 勾选目标 app,然后重试。"
        }
        return nil
    }
}
