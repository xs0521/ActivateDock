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
}
