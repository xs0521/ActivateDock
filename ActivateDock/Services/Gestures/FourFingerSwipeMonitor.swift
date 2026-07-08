//
//  FourFingerSwipeMonitor.swift
//  ActivateDock
//

import Foundation
import OpenMultitouchSupport

@MainActor
final class FourFingerSwipeMonitor {
    static let shared = FourFingerSwipeMonitor()

    var onSwipeDown: (() -> Void)?

    private let manager = OMSManager.shared
    private var detector = FourFingerSwipeDetector()
    private var task: Task<Void, Never>?

    private init() {}

    func startIfEnabled() {
        FourFingerSwipePreferences.isEnabled ? start() : stop()
    }

    func setEnabled(_ enabled: Bool) {
        FourFingerSwipePreferences.isEnabled = enabled
        enabled ? start() : stop()
    }

    func start() {
        guard task == nil else { return }
        guard manager.startListening() else {
            NSLog("[FourFingerSwipe] failed to start listener")
            return
        }

        let stream = manager.touchDataStream
        task = Task { [weak self] in
            for await touches in stream {
                guard !Task.isCancelled else { break }
                await self?.handle(touches)
            }
        }
        NSLog("[FourFingerSwipe] listener started")
    }

    func stop() {
        guard task != nil || manager.isListening else { return }
        task?.cancel()
        task = nil
        _ = manager.stopListening()
        detector.reset()
        NSLog("[FourFingerSwipe] listener stopped")
    }

    private func handle(_ touches: [OMSTouchData]) {
        if detector.consume(touches) {
            onSwipeDown?()
        }
    }
}
