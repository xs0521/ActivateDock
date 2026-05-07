//
//  ViewController+Search.swift
//  ActivateDock
//

import Cocoa

extension ViewController: NSSearchFieldDelegate {

    func loadInstalledApps() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let apps = InstalledAppsCatalog.loadAll()
            DispatchQueue.main.async { self?.installedApps = apps }
        }
    }

    func installCmdQMonitor() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers?.lowercased() == "q" {
                NSApp.terminate(nil)
                return nil
            }
            return event
        }
    }

    func updateForSearchText(_ text: String) {
        searchDebounceWorkItem?.cancel()
        searchDebounceWorkItem = nil
        searchClearButton.isHidden = text.isEmpty
        updateSearchHint(for: text)
        let q = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty {
            alfredRunner.cancel()
            searchResults = []
            searchResultsTable.reloadData()
            searchBackground.isHidden = true
            searchScrollView.isHidden = true
            scrollView.isHidden = false
            return
        }

        searchBackground.isHidden = false
        searchScrollView.isHidden = false
        scrollView.isHidden = true

        if let match = WorkflowRegistry.shared.match(input: q) {
            runAlfred(workflow: match.workflow, query: match.query)
            return
        }

        alfredRunner.cancel()
        let apps = InstalledAppsCatalog.search(q, in: installedApps)
        searchResults = apps.map(SearchRow.app)
        searchResultsTable.reloadData()
        if !searchResults.isEmpty {
            searchResultsTable.selectRowIndexes([0], byExtendingSelection: false)
            searchResultsTable.scrollRowToVisible(0)
        }
    }

    private func runAlfred(workflow: Workflow, query: String) {
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
                let detail: String
                switch err {
                case .launchFailed(let e): detail = "launch failed: \(e.localizedDescription)"
                case .nonZeroExit(let code, let stderr): detail = "exit \(code): \(stderr.prefix(200))"
                case .decodeFailed(_, let raw): detail = "decode failed. raw: \(raw.prefix(200))"
                case .cancelled: return
                }
                let item = AlfredItem(title: "[error] yd plugin", subtitle: detail, arg: nil, icon: nil)
                self.searchResults = [.alfred(item)]
                self.searchResultsTable.reloadData()
            }
        }
    }

    func controlTextDidChange(_ obj: Notification) {
        searchDebounceWorkItem?.cancel()
        let text = searchField.stringValue
        searchClearButton.isHidden = text.isEmpty
        updateSearchHint(for: text)
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            updateForSearchText(text)
            return
        }
        let work = DispatchWorkItem { [weak self] in
            self?.updateForSearchText(text)
        }
        searchDebounceWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: work)
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        switch commandSelector {
        case #selector(NSResponder.cancelOperation(_:)):
            if !searchField.stringValue.isEmpty {
                searchField.stringValue = ""
                updateForSearchText("")
            } else {
                view.window?.orderOut(nil)
            }
            return true
        case #selector(NSResponder.moveDown(_:)):
            moveSearchSelection(by: 1)
            return true
        case #selector(NSResponder.moveUp(_:)):
            moveSearchSelection(by: -1)
            return true
        default:
            return false
        }
    }

    private func moveSearchSelection(by delta: Int) {
        guard !searchResults.isEmpty else { return }
        let current = searchResultsTable.selectedRow
        let next = max(0, min(searchResults.count - 1, current + delta))
        searchResultsTable.selectRowIndexes([next], byExtendingSelection: false)
        searchResultsTable.scrollRowToVisible(next)
    }

    @objc func handleSearchClear(_ sender: Any?) {
        searchField.stringValue = ""
        updateForSearchText("")
        view.window?.makeFirstResponder(searchField)
    }

    @objc func handleSearchSubmit(_ sender: Any?) {
        let trimmed = searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            updateForSearchText("")
            return
        }
        if let command = SearchCommand.parse(trimmed) {
            NSWorkspace.shared.open(command.url)
            searchField.stringValue = ""
            updateForSearchText("")
            view.window?.orderOut(nil)
            return
        }
        let row: Int
        if searchResultsTable.selectedRow >= 0 {
            row = searchResultsTable.selectedRow
        } else if !searchResults.isEmpty {
            row = 0
        } else {
            return
        }
        guard searchResults.indices.contains(row) else { return }
        switch searchResults[row] {
        case .app(let app):
            NSWorkspace.shared.openApplication(at: app.url,
                                               configuration: NSWorkspace.OpenConfiguration(),
                                               completionHandler: nil)
        case .alfred(let item):
            if let arg = item.arg, !arg.isEmpty {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(arg, forType: .string)
            }
        }
        searchField.stringValue = ""
        updateForSearchText("")
        view.window?.orderOut(nil)
    }

}
