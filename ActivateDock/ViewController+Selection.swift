//
//  ViewController+Selection.swift
//  ActivateDock
//

import Cocoa

extension ViewController {

    var allButtons: [AppIconButton] {
        var result: [AppIconButton] = []
        guard collectionView.numberOfSections > 0 else { return result }
        for index in 0..<collectionView.numberOfItems(inSection: 0) {
            if let item = collectionView.item(at: IndexPath(item: index, section: 0)) as? SectionCollectionItem {
                result.append(contentsOf: item.buttons)
            }
        }
        return result
    }

    func moveSelection(forward: Bool) {
        let buttons = allButtons
        guard !buttons.isEmpty else { return }
        if forward {
            selectedIndex = (selectedIndex + 1) % buttons.count
        } else {
            selectedIndex = (selectedIndex - 1 + buttons.count) % buttons.count
        }
        updateSelectionUI()
    }

    func updateSelectionUI() {
        for (index, button) in allButtons.enumerated() {
            button.setFocused(index == selectedIndex)
        }
    }

    func activateSelectedApp() {
        let buttons = allButtons
        guard selectedIndex >= 0, selectedIndex < buttons.count else { return }
        let target = buttons[selectedIndex].app.app
        if target.activate(options: [.activateAllWindows]) {
            NSApp.hide(nil)
        }
    }

    func handleAppTapped(_ button: AppIconButton) {
        if let index = allButtons.firstIndex(where: { $0 === button }) {
            selectedIndex = index
            updateSelectionUI()
            activateSelectedApp()
        }
    }
}
