//
//  ViewController+CollectionView.swift
//  ActivateDock
//

import Cocoa

extension ViewController: NSCollectionViewDataSource {
    func numberOfSections(in collectionView: NSCollectionView) -> Int { 1 }

    func collectionView(_ collectionView: NSCollectionView, numberOfItemsInSection section: Int) -> Int {
        groupedApps.count
    }

    func collectionView(_ collectionView: NSCollectionView,
                        itemForRepresentedObjectAt indexPath: IndexPath) -> NSCollectionViewItem {
        let item = collectionView.makeItem(withIdentifier: SectionCollectionItem.identifier, for: indexPath)
        guard let sectionItem = item as? SectionCollectionItem else { return item }
        sectionItem.configure(with: groupedApps[indexPath.item])
        sectionItem.onAppTapped = { [weak self] button in
            self?.handleAppTapped(button)
        }
        sectionItem.onDragStart = { [weak self, weak sectionItem] mouse in
            guard let self, let cell = sectionItem else { return }
            self.cardDragStart(cell: cell, mouseInWindow: mouse)
        }
        sectionItem.onDragMove = { [weak self] mouse in
            self?.cardDragMove(mouseInWindow: mouse)
        }
        sectionItem.onDragEnd = { [weak self] mouse in
            self?.cardDragEnd(mouseInWindow: mouse)
        }
        DispatchQueue.main.async { [weak self] in
            self?.updateSelectionUI()
        }
        return sectionItem
    }
}

extension ViewController: NSCollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: NSCollectionView,
                        layout collectionViewLayout: NSCollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> NSSize {
        let width = max(collectionView.bounds.width, 200)
        return NSSize(width: width, height: SectionCollectionItem.itemHeight)
    }
}

extension ViewController: NSCollectionViewDelegate {
    func collectionView(_ collectionView: NSCollectionView,
                        canDragItemsAt indexPaths: Set<IndexPath>,
                        with event: NSEvent) -> Bool {
        false
    }
}
