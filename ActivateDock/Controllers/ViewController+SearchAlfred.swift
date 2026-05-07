//
//  ViewController+SearchAlfred.swift
//  ActivateDock
//
//  Plugin (Alfred Script Filter) execution path: kicks off the runner,
//  shows a loading row while the subprocess is running, and renders
//  failures as a polished error row.
//

import Cocoa

extension ViewController {

    func runAlfred(workflow: Workflow, query: String) {
        searchResults = [.loading]
        searchResultsTable.reloadData()
        searchResultsTable.deselectAll(nil)

        alfredRunner.run(workflow: workflow, query: query) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let items):
                let resolved = workflow.resolvingIconPaths(in: items)
                self.searchResults = resolved.map(SearchRow.alfred)
                self.searchResultsTable.reloadData()
                if !self.searchResults.isEmpty {
                    self.searchResultsTable.selectRowIndexes([0], byExtendingSelection: false)
                    self.searchResultsTable.scrollRowToVisible(0)
                }
            case .failure(.cancelled):
                return
            case .failure(let err):
                let (title, detail) = Self.errorPresentation(for: err, workflow: workflow)
                self.searchResults = [.error(title: title, detail: detail)]
                self.searchResultsTable.reloadData()
            }
        }
    }

    private static func errorPresentation(for err: AlfredRunnerError,
                                          workflow: Workflow) -> (title: String, detail: String) {
        switch err {
        case .launchFailed(let e):
            return ("\(workflow.name) · 启动失败", e.localizedDescription)
        case .nonZeroExit(let code, let stderr):
            if let hint = permissionHint(stderr: stderr) {
                return ("\(workflow.name) · 需要权限", hint)
            }
            let firstLine = stderr
                .split(whereSeparator: \.isNewline)
                .first
                .map(String.init) ?? ""
            let trimmed = firstLine.trimmingCharacters(in: .whitespaces)
            let detail = trimmed.isEmpty ? "exit code \(code)" : "exit \(code): \(trimmed.prefix(180))"
            return ("\(workflow.name) · 运行错误", detail)
        case .decodeFailed(_, let raw):
            let snippet = raw.trimmingCharacters(in: .whitespacesAndNewlines).prefix(180)
            return ("\(workflow.name) · 输出解析失败", String(snippet))
        case .cancelled:
            return ("", "")
        }
    }

    // Maps known macOS TCC error fingerprints to an actionable hint.
    // TCC denials surface through stderr text (the OS doesn't give us
    // a typed errno), so we keyword-match. The full stderr is still in
    // NSLog under the [plugin:<bundleId>] tag for power-user debugging.
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
