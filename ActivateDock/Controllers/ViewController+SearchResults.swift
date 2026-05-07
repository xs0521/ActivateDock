//
//  ViewController+SearchResults.swift
//  ActivateDock
//

import Cocoa

extension ViewController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int { searchResults.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell: SearchResultCell
        if let reused = tableView.makeView(withIdentifier: SearchResultCell.reuseIdentifier, owner: self) as? SearchResultCell {
            cell = reused
        } else {
            cell = SearchResultCell(frame: .zero)
            cell.identifier = SearchResultCell.reuseIdentifier
        }
        if searchResults.indices.contains(row) {
            switch searchResults[row] {
            case .app(let app): cell.configure(with: app)
            case .alfred(let item): cell.configure(alfredItem: item)
            case .loading: cell.configureLoading()
            case .error(let title, let detail): cell.configureError(title: title, detail: detail)
            }
        }
        cell.setSelected(tableView.selectedRow == row)
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let visible = searchResultsTable.rows(in: searchResultsTable.visibleRect)
        let selected = searchResultsTable.selectedRow
        for row in visible.location..<NSMaxRange(visible) {
            guard let cell = searchResultsTable.view(atColumn: 0, row: row, makeIfNecessary: false) as? SearchResultCell else { continue }
            cell.setSelected(row == selected)
        }
    }
}
