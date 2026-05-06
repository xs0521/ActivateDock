//
//  ViewController+Search.swift
//  ActivateDock
//

import Cocoa

extension ViewController: NSSearchFieldDelegate, NSTableViewDataSource, NSTableViewDelegate {

    func setupSearch() {
        searchField.placeholderString = "search"
        searchField.font = .systemFont(ofSize: 22)
        searchField.sendsWholeSearchString = true
        searchField.sendsSearchStringImmediately = false
        searchField.isBezeled = false
        searchField.drawsBackground = false
        searchField.focusRingType = .none
        (searchField.cell as? NSSearchFieldCell)?.searchButtonCell = nil
        searchField.delegate = self
        searchField.target = self
        searchField.action = #selector(handleSearchSubmit(_:))

        searchFieldBox.material = .menu
        searchFieldBox.blendingMode = .withinWindow
        searchFieldBox.state = .active
        searchFieldBox.wantsLayer = true
        searchFieldBox.layer?.cornerRadius = 20
        searchFieldBox.layer?.masksToBounds = true

        searchBackground.material = .menu
        searchBackground.blendingMode = .withinWindow
        searchBackground.state = .active
        searchBackground.wantsLayer = true
        searchBackground.layer?.cornerRadius = 12
        searchBackground.layer?.masksToBounds = true
        searchBackground.isHidden = true

        searchScrollView.drawsBackground = false
        searchScrollView.hasVerticalScroller = true
        searchScrollView.hasHorizontalScroller = false
        searchScrollView.automaticallyAdjustsContentInsets = false
        searchScrollView.scrollerStyle = .overlay

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        column.resizingMask = [.autoresizingMask]
        searchResultsTable.addTableColumn(column)
        searchResultsTable.headerView = nil
        searchResultsTable.style = .plain
        searchResultsTable.backgroundColor = .clear
        searchResultsTable.gridStyleMask = []
        searchResultsTable.intercellSpacing = NSSize(width: 0, height: 4)
        searchResultsTable.rowHeight = 44
        searchResultsTable.allowsEmptySelection = false
        searchResultsTable.allowsMultipleSelection = false
        searchResultsTable.dataSource = self
        searchResultsTable.delegate = self
        searchResultsTable.target = self
        searchResultsTable.doubleAction = #selector(handleSearchSubmit(_:))
        searchScrollView.documentView = searchResultsTable
    }

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
        let q = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty {
            searchResults = []
            searchResultsTable.reloadData()
            searchBackground.isHidden = true
            return
        }
        searchResults = InstalledAppsCatalog.search(q, in: installedApps)
        searchResultsTable.reloadData()
        searchBackground.isHidden = false
        if !searchResults.isEmpty {
            searchResultsTable.selectRowIndexes([0], byExtendingSelection: false)
            searchResultsTable.scrollRowToVisible(0)
        }
    }

    func controlTextDidChange(_ obj: Notification) {
        updateForSearchText(searchField.stringValue)
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

    @objc private func handleSearchSubmit(_ sender: Any?) {
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
        NSWorkspace.shared.open(app.url)
        searchField.stringValue = ""
        updateForSearchText("")
        view.window?.orderOut(nil)
    }

    func numberOfRows(in tableView: NSTableView) -> Int { searchResults.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = SearchResultCell(frame: .zero)
        if searchResults.indices.contains(row) { cell.configure(with: searchResults[row]) }
        return cell
    }
}
