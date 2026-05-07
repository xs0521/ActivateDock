//
//  SearchRow.swift
//  ActivateDock
//

import Foundation

enum SearchRow {
    case app(InstalledApp)
    case alfred(AlfredItem)
    case loading
    case error(title: String, detail: String)
}
