//
//  ViewController+NewCategory.swift
//  ActivateDock
//

import Cocoa

extension ViewController {

    func handlePlusTapped(button: AppIconButton) {
        guard let location = locate(app: button.app) else { return }
        let app = groupedApps[location.group].items.remove(at: location.item)

        if groupedApps[location.group].items.isEmpty {
            groupedApps.remove(at: location.group)
        }

        let title = nextCategoryTitle()
        let color = nextAccentColor()
        let newGroup = AppGroup(title: title, accentColor: color, items: [app])
        let insertAt = groupedApps.firstIndex(where: { $0.title == "其他" }) ?? groupedApps.count
        groupedApps.insert(newGroup, at: insertAt)

        collectionView.reloadData()
        saveLayout()
        DispatchQueue.main.async { [weak self] in
            self?.fitWindowHeightToContent()
        }
    }

    private func locate(app: RunningApp) -> (group: Int, item: Int)? {
        let target = app.app
        for (i, group) in groupedApps.enumerated() {
            if let j = group.items.firstIndex(where: { $0.app == target }) {
                return (i, j)
            }
        }
        return nil
    }

    private func nextCategoryTitle() -> String {
        let base = "新分类"
        let existing = Set(groupedApps.map { $0.title })
        if !existing.contains(base) { return base }
        var n = 2
        while existing.contains("\(base) \(n)") { n += 1 }
        return "\(base) \(n)"
    }

    private func nextAccentColor() -> NSColor {
        let palette: [NSColor] = [.systemTeal, .systemOrange, .systemMint, .systemIndigo, .systemYellow, .systemBrown]
        let used = Set(groupedApps.map { $0.accentColor })
        return palette.first { !used.contains($0) } ?? .systemTeal
    }
}
