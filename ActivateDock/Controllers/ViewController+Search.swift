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
            searchResults = []
            searchResultsTable.reloadData()
            searchBackground.isHidden = true
            searchScrollView.isHidden = true
            scrollView.isHidden = false
            return
        }
        searchResults = InstalledAppsCatalog.search(q, in: installedApps)
        searchResultsTable.reloadData()
        searchBackground.isHidden = false
        searchScrollView.isHidden = false
        scrollView.isHidden = true
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
        let app = searchResults[row]
        NSWorkspace.shared.openApplication(at: app.url,
                                           configuration: NSWorkspace.OpenConfiguration(),
                                           completionHandler: nil)
        searchField.stringValue = ""
        updateForSearchText("")
        view.window?.orderOut(nil)
    }

}
