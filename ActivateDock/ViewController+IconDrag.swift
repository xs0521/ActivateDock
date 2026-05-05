//
//  ViewController+IconDrag.swift
//  ActivateDock
//

import Cocoa

extension ViewController {

    func iconDragStart(cell: SectionCollectionItem, button: AppIconButton, mouseInWindow: NSPoint) {
        cleanupIconDrag()

        guard let groupIndex = collectionView.indexPath(for: cell)?.item,
              let itemIndex = cell.buttons.firstIndex(of: button) else { return }
        guard let snapshot = iconSnapshotImage(of: button) else { return }

        let frameInPanel = panelContent.convert(button.bounds, from: button)

        let overlay = NSImageView(frame: frameInPanel)
        overlay.image = snapshot
        overlay.imageScaling = .scaleNone
        overlay.wantsLayer = true
        overlay.layer?.shadowColor = NSColor.black.cgColor
        overlay.layer?.shadowOpacity = 0.45
        overlay.layer?.shadowRadius = 14
        overlay.layer?.shadowOffset = NSSize(width: 0, height: -2)
        overlay.layer?.masksToBounds = false
        panelContent.addSubview(overlay)

        button.alphaValue = 0

        iconDragOverlay = overlay
        iconDragSourceGroup = groupIndex
        iconDragSourceItem = itemIndex
        iconDragMouseStart = mouseInWindow
        iconDragOverlayStartOrigin = frameInPanel.origin
    }

    func iconDragMove(mouseInWindow: NSPoint) {
        guard let overlay = iconDragOverlay,
              let mouseStart = iconDragMouseStart,
              let startOrigin = iconDragOverlayStartOrigin else { return }

        let dx = mouseInWindow.x - mouseStart.x
        let dy = mouseInWindow.y - mouseStart.y
        overlay.frame.origin = NSPoint(x: startOrigin.x + dx, y: startOrigin.y + dy)

        let center = NSPoint(x: overlay.frame.midX, y: overlay.frame.midY)
        let newTarget = groupIndex(containingPanelPoint: center)

        if newTarget != iconDragTargetGroup {
            applyDropHighlight(group: iconDragTargetGroup, active: false)
            iconDragTargetGroup = newTarget
            if let target = newTarget, target != iconDragSourceGroup {
                applyDropHighlight(group: target, active: true)
            }
        }
    }

    func iconDragEnd(mouseInWindow: NSPoint) {
        guard let overlay = iconDragOverlay,
              let sourceGroup = iconDragSourceGroup,
              let sourceItem = iconDragSourceItem else {
            cleanupIconDrag()
            return
        }

        applyDropHighlight(group: iconDragTargetGroup, active: false)

        let canDrop = iconDragTargetGroup != nil
            && iconDragTargetGroup != sourceGroup
            && groupedApps.indices.contains(sourceGroup)
            && groupedApps[sourceGroup].items.indices.contains(sourceItem)

        if canDrop, let target = iconDragTargetGroup, groupedApps.indices.contains(target) {
            let app = groupedApps[sourceGroup].items.remove(at: sourceItem)
            groupedApps[target].items.append(app)
            cleanupIconDrag()
            collectionView.reloadData()
            return
        }

        guard let sourceFrame = sourceButtonFrameInPanel() else {
            cleanupIconDrag()
            return
        }

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.20
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            overlay.animator().frame = sourceFrame
        }, completionHandler: { [weak self] in
            self?.cleanupIconDrag()
        })
    }

    private func groupIndex(containingPanelPoint p: NSPoint) -> Int? {
        for i in 0..<groupedApps.count {
            guard let attrs = collectionView.collectionViewLayout?
                .layoutAttributesForItem(at: IndexPath(item: i, section: 0)) else { continue }
            let frameInPanel = panelContent.convert(attrs.frame, from: collectionView)
            if frameInPanel.contains(p) { return i }
        }
        return nil
    }

    private func applyDropHighlight(group: Int?, active: Bool) {
        guard let group else { return }
        guard let cell = collectionView.item(at: IndexPath(item: group, section: 0)) as? SectionCollectionItem else { return }
        cell.setDropHighlight(active)
    }

    private func sourceButtonFrameInPanel() -> NSRect? {
        guard let group = iconDragSourceGroup,
              let item = iconDragSourceItem,
              let cell = collectionView.item(at: IndexPath(item: group, section: 0)) as? SectionCollectionItem,
              cell.buttons.indices.contains(item) else { return nil }
        let button = cell.buttons[item]
        return panelContent.convert(button.bounds, from: button)
    }

    private func cleanupIconDrag() {
        iconDragOverlay?.removeFromSuperview()
        iconDragOverlay = nil

        if let group = iconDragSourceGroup,
           let item = iconDragSourceItem,
           let cell = collectionView.item(at: IndexPath(item: group, section: 0)) as? SectionCollectionItem,
           cell.buttons.indices.contains(item) {
            cell.buttons[item].alphaValue = 1
        }

        iconDragSourceGroup = nil
        iconDragSourceItem = nil
        iconDragTargetGroup = nil
        iconDragMouseStart = nil
        iconDragOverlayStartOrigin = nil
    }

    private func iconSnapshotImage(of view: NSView) -> NSImage? {
        guard view.bounds.width > 0, view.bounds.height > 0,
              let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return nil }
        view.cacheDisplay(in: view.bounds, to: rep)
        let image = NSImage(size: view.bounds.size)
        image.addRepresentation(rep)
        return image
    }
}
