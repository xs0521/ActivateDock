//
//  DraggableSectionView.swift
//  ActivateDock
//

import Cocoa

final class DraggableSectionView: NSView {
    var onDragStart: ((NSPoint) -> Void)?
    var onDragMove: ((NSPoint) -> Void)?
    var onDragEnd: ((NSPoint) -> Void)?

    private var pressStart: NSPoint?
    private var isDragging = false
    private static let threshold: CGFloat = 4

    override func mouseDown(with event: NSEvent) {
        pressStart = event.locationInWindow
        isDragging = false
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = pressStart else { return }
        let p = event.locationInWindow
        if !isDragging {
            if abs(p.y - start.y) > Self.threshold || abs(p.x - start.x) > Self.threshold {
                isDragging = true
                onDragStart?(p)
            }
            return
        }
        onDragMove?(p)
    }

    override func mouseUp(with event: NSEvent) {
        if isDragging {
            onDragEnd?(event.locationInWindow)
        }
        pressStart = nil
        isDragging = false
    }
}
