//
//  ViewController+CardDrag.swift
//  ActivateDock
//

import Cocoa

extension ViewController {

    func cardDragStart(cell: SectionCollectionItem, mouseInWindow: NSPoint) {
        cleanupCardDrag()

        guard let index = collectionView.indexPath(for: cell)?.item else { return }
        guard let snapshot = snapshotImage(of: cell.view) else { return }

        let frameInPanel = panelContent.convert(cell.view.bounds, from: cell.view)

        let overlay = NSImageView(frame: frameInPanel)
        overlay.image = snapshot
        overlay.imageScaling = .scaleNone
        overlay.wantsLayer = true
        overlay.layer?.shadowColor = NSColor.black.cgColor
        overlay.layer?.shadowOpacity = 0.35
        overlay.layer?.shadowRadius = 16
        overlay.layer?.shadowOffset = NSSize(width: 0, height: -2)
        overlay.layer?.masksToBounds = false
        panelContent.addSubview(overlay)

        cell.view.alphaValue = 0

        cardDragOverlay = overlay
        cardDragSourceIndex = index
        cardDragMouseStart = mouseInWindow
        cardDragOverlayStartOrigin = frameInPanel.origin
    }

    func cardDragMove(mouseInWindow: NSPoint) {
        guard let overlay = cardDragOverlay,
              let mouseStart = cardDragMouseStart,
              let startOrigin = cardDragOverlayStartOrigin,
              let activeIndex = cardDragSourceIndex else { return }

        let dy = mouseInWindow.y - mouseStart.y
        overlay.frame.origin = NSPoint(x: startOrigin.x, y: startOrigin.y + dy)

        let overlayCenterY = overlay.frame.midY
        var targetIndex = activeIndex
        for i in 0..<groupedApps.count {
            guard let attrs = collectionView.collectionViewLayout?
                .layoutAttributesForItem(at: IndexPath(item: i, section: 0)) else { continue }
            let frameInPanel = panelContent.convert(attrs.frame, from: collectionView)
            if overlayCenterY >= frameInPanel.minY && overlayCenterY <= frameInPanel.maxY {
                targetIndex = i
                break
            }
        }

        if targetIndex != activeIndex {
            let moved = groupedApps.remove(at: activeIndex)
            groupedApps.insert(moved, at: targetIndex)
            cardDragSourceIndex = targetIndex

            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.22
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                collectionView.animator().moveItem(
                    at: IndexPath(item: activeIndex, section: 0),
                    to: IndexPath(item: targetIndex, section: 0)
                )
            }
        }

        keepSourceCellHidden()
    }

    func cardDragEnd(mouseInWindow: NSPoint) {
        guard let overlay = cardDragOverlay,
              let activeIndex = cardDragSourceIndex,
              let attrs = collectionView.collectionViewLayout?
                .layoutAttributesForItem(at: IndexPath(item: activeIndex, section: 0)) else {
            cleanupCardDrag()
            return
        }

        let targetFrame = panelContent.convert(attrs.frame, from: collectionView)
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.20
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            overlay.animator().frame = targetFrame
        }, completionHandler: { [weak self] in
            self?.cleanupCardDrag()
        })
    }

    private func keepSourceCellHidden() {
        for i in 0..<groupedApps.count {
            guard let cell = collectionView.item(at: IndexPath(item: i, section: 0)) else { continue }
            cell.view.alphaValue = (i == cardDragSourceIndex) ? 0 : 1
        }
    }

    private func cleanupCardDrag() {
        cardDragOverlay?.removeFromSuperview()
        cardDragOverlay = nil
        for i in 0..<max(groupedApps.count, collectionView.numberOfItems(inSection: 0)) {
            if let cell = collectionView.item(at: IndexPath(item: i, section: 0)) {
                cell.view.alphaValue = 1
            }
        }
        cardDragSourceIndex = nil
        cardDragMouseStart = nil
        cardDragOverlayStartOrigin = nil
    }

    private func snapshotImage(of view: NSView) -> NSImage? {
        guard view.bounds.width > 0, view.bounds.height > 0,
              let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return nil }
        view.cacheDisplay(in: view.bounds, to: rep)
        let image = NSImage(size: view.bounds.size)
        image.addRepresentation(rep)
        return image
    }
}
