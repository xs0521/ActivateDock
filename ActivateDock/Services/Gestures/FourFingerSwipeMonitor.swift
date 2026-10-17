//
//  FourFingerSwipeMonitor.swift
//  ActivateDock
//

import Foundation

@MainActor
final class FourFingerSwipeMonitor {
    static let shared = FourFingerSwipeMonitor()

    var onSwipeDown: (() -> Void)?

    private let reader = MultitouchReader()
    private var detectors: [UInt: FourFingerSwipeDetector] = [:]
    private var isListening = false

    private init() {
        reader.onFrame = { [weak self] device, touches in
            self?.handle(touches, from: device)
        }
        reader.onDevicesChanged = { [weak self] in
            self?.detectors.removeAll()
        }
    }

    func startIfEnabled() {
        FourFingerSwipePreferences.isEnabled ? start() : stop()
    }

    func setEnabled(_ enabled: Bool) {
        FourFingerSwipePreferences.isEnabled = enabled
        enabled ? start() : stop()
    }

    func start() {
        guard !isListening else { return }
        isListening = reader.start()
        NSLog("[FourFingerSwipe] listener %@", isListening ? "started" : "failed to start")
    }

    func stop() {
        guard isListening else { return }
        reader.stop()
        isListening = false
        detectors.removeAll()
        NSLog("[FourFingerSwipe] listener stopped")
    }

    private func handle(_ touches: [ADTouch], from device: UInt) {
        // Frames from another trackpad must never reset or complete this swipe.
        if detectors[device, default: FourFingerSwipeDetector()].consume(touches) {
            onSwipeDown?()
        }
    }
}
