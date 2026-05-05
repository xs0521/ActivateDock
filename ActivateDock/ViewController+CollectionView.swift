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
        true
    }

    func collectionView(_ collectionView: NSCollectionView,
                        pasteboardWriterForItemAt indexPath: IndexPath) -> NSPasteboardWriting? {
        let item = NSPasteboardItem()
        item.setString(String(indexPath.item), forType: ViewController.sectionPasteboardType)
        return item
    }

    func collectionView(_ collectionView: NSCollectionView,
                        draggingSession session: NSDraggingSession,
                        willBeginAt screenPoint: NSPoint,
                        forItemsAt indexPaths: Set<IndexPath>) {
        liveDragSourceIndex = indexPaths.first?.item
        session.animatesToStartingPositionsOnCancelOrFail = false
        session.draggingFormation = .none
    }

    func collectionView(_ collectionView: NSCollectionView,
                        draggingSession session: NSDraggingSession,
                        endedAt screenPoint: NSPoint,
                        dragOperation operation: NSDragOperation) {
        liveDragSourceIndex = nil
        DispatchQueue.main.async { [weak self] in
            self?.updateSelectionUI()
        }
    }

    func collectionView(_ collectionView: NSCollectionView,
                        validateDrop draggingInfo: NSDraggingInfo,
                        proposedIndexPath: AutoreleasingUnsafeMutablePointer<NSIndexPath>,
                        dropOperation proposedDropOperation: UnsafeMutablePointer<NSCollectionView.DropOperation>) -> NSDragOperation {
        if proposedDropOperation.pointee == .on {
            proposedDropOperation.pointee = .before
        }

        guard let source = liveDragSourceIndex,
              source >= 0, source < groupedApps.count else { return .move }

        let proposed = (proposedIndexPath.pointee as IndexPath).item
        var target = proposed
        if target > source { target -= 1 }
        target = max(0, min(target, groupedApps.count - 1))

        if target != source {
            let moved = groupedApps.remove(at: source)
            groupedApps.insert(moved, at: target)
            liveDragSourceIndex = target

            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.22
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                collectionView.animator().moveItem(
                    at: IndexPath(item: source, section: 0),
                    to: IndexPath(item: target, section: 0)
                )
            }
        }

        proposedIndexPath.pointee = NSIndexPath(forItem: liveDragSourceIndex ?? source, inSection: 0)
        return .move
    }

    func collectionView(_ collectionView: NSCollectionView,
                        acceptDrop draggingInfo: NSDraggingInfo,
                        indexPath: IndexPath,
                        dropOperation: NSCollectionView.DropOperation) -> Bool {
        liveDragSourceIndex = nil
        return true
    }
}
