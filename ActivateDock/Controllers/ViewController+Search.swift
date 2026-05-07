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

        // Match against the raw text (not the trimmed `q`) so that
        // "shi " with a trailing space still resolves to keyword=shi,
        // query="" — Alfred fires the script filter on bare keyword+
        // space and plugins can render their initial result set.
        if let match = WorkflowRegistry.shared.match(input: text) {
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
        let delay = Self.debounceDelay(for: text)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private static func debounceDelay(for text: String) -> TimeInterval {
        guard let space = text.firstIndex(of: " ") else { return 0.12 }
        let keyword = String(text[..<space])
        return WorkflowRegistry.shared.workflow(forKeyword: keyword) != nil ? 0.25 : 0.12
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
            handleAlfredArg(item.arg)
        case .loading, .error:
            return
        }
        searchField.stringValue = ""
        updateForSearchText("")
        view.window?.orderOut(nil)
    }

    private func handleAlfredArg(_ arg: String?) {
        guard let arg, !arg.isEmpty else { return }
        if let url = Self.openableURL(from: arg) {
            NSWorkspace.shared.open(url)
        } else {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(arg, forType: .string)
        }
    }

    // Treat the arg as URL when it parses with a scheme we recognise.
    // Plugins frequently use arg as a URL (Safari history, tabs, link
    // openers); when it isn't a URL (translation result, profile id),
    // we fall back to clipboard so the value isn't lost.
    private static let openableSchemes: Set<String> = [
        "http", "https", "file", "mailto", "ftp", "ftps", "ssh"
    ]

    private static func openableURL(from arg: String) -> URL? {
        guard let url = URL(string: arg),
              let scheme = url.scheme?.lowercased(),
              openableSchemes.contains(scheme)
        else { return nil }
        return url
    }
}
