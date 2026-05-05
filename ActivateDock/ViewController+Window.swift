//
//  ViewController+Window.swift
//  ActivateDock
//

import Cocoa

extension ViewController {

    func configureWindowChrome() {
        guard let window = view.window else { return }
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.toolbar = nil
        window.styleMask.insert(.fullSizeContentView)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.invalidateShadow()
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true

        window.setFrameAutosaveName("")
        window.minSize = NSSize(width: 640, height: 320)

        DispatchQueue.main.async { [weak self, weak window] in
            guard let self, let window else { return }
            let screen = NSScreen.screens.first ?? NSScreen.main
            let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
            let width = min(max(visible.width * 0.55, 960), 1600)
            let height = min(max(visible.height * 0.65, 640), 1100)
            let preferred = NSSize(width: width, height: height)
            let origin = NSPoint(
                x: visible.midX - preferred.width / 2,
                y: visible.midY - preferred.height / 2
            )
            window.setFrame(NSRect(origin: origin, size: preferred), display: true, animate: false)
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            self.fitWindowHeightToContent()
        }
    }

    func fitWindowHeightToContent() {
        guard let window = view.window, !groupedApps.isEmpty else { return }

        let cardH = SectionCollectionItem.itemHeight
        let spacing: CGFloat = 12
        let verticalPadding: CGFloat = 32 * 2
        let n = CGFloat(groupedApps.count)
        let contentH = n * cardH + max(n - 1, 0) * spacing
        let needed = contentH + verticalPadding

        let screen = window.screen ?? NSScreen.screens.first ?? NSScreen.main
        let visibleH = screen?.visibleFrame.height ?? 900
        let target = min(needed, visibleH * 0.9)

        var frame = window.frame
        guard abs(frame.size.height - target) > 0.5 else { return }
        let delta = target - frame.size.height
        frame.size.height = target
        frame.origin.y -= delta / 2
        window.setFrame(frame, display: true, animate: false)
        window.invalidateShadow()
    }
}
