//
//  ViewController+Persistence.swift
//  ActivateDock
//

import Cocoa

extension ViewController {
    func saveLayout() {
        let snapshot = groupedApps.map { LayoutStore.encode(group: $0) }
        LayoutStore.save(snapshot)
    }
}
