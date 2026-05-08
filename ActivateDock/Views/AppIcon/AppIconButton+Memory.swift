//
//  AppIconButton+Memory.swift
//  ActivateDock
//

import Cocoa

extension AppIconButton {
    func setupMemoryLabel() {
        memoryBackdrop.translatesAutoresizingMaskIntoConstraints = false
        memoryBackdrop.wantsLayer = true
        memoryBackdrop.layer?.cornerRadius = (Self.memoryLabelHeight + 2) / 2
        memoryBackdrop.layer?.backgroundColor = Self.backdropColor
        memoryBackdrop.layer?.masksToBounds = false
        let backdropShadow = NSShadow()
        backdropShadow.shadowColor = NSColor.black.withAlphaComponent(0.45)
        backdropShadow.shadowOffset = NSSize(width: 0, height: -1)
        backdropShadow.shadowBlurRadius = 2.5
        memoryBackdrop.shadow = backdropShadow
        addSubview(memoryBackdrop)

        memoryLabel.translatesAutoresizingMaskIntoConstraints = false
        memoryLabel.font = .monospacedDigitSystemFont(ofSize: 9.5, weight: .medium)
        memoryLabel.textColor = .white
        memoryLabel.alignment = .center
        memoryLabel.lineBreakMode = .byClipping
        memoryLabel.maximumNumberOfLines = 1
        memoryLabel.cell?.usesSingleLineMode = true
        memoryLabel.stringValue = ""
        memoryLabel.setContentHuggingPriority(.required, for: .horizontal)
        memoryLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        memoryBackdrop.addSubview(memoryLabel)
    }

    func startMemoryTracking() {
        guard pid > 0 else { return }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryUpdate(_:)),
            name: MemoryMonitor.didUpdateNotification,
            object: nil
        )
        MemoryMonitor.shared.track(pid)
        if let cached = MemoryMonitor.shared.lastReading(for: pid) {
            memoryLabel.stringValue = MemoryProbe.format(cached)
        } else {
            isLoading = true
        }
    }

    @objc private func handleMemoryUpdate(_ note: Notification) {
        guard let info = note.userInfo,
              let updated = info[MemoryMonitor.pidKey] as? pid_t,
              updated == pid else { return }
        if let bytes = info[MemoryMonitor.bytesKey] as? UInt64 {
            isLoading = false
            memoryLabel.stringValue = MemoryProbe.format(bytes)
        } else {
            memoryLabel.stringValue = ""
            isLoading = true
        }
    }

    func startLoadingAnimation() {
        memoryLabel.stringValue = ""
        let breath = CABasicAnimation(keyPath: "backgroundColor")
        breath.fromValue = Self.breathLowColor
        breath.toValue = Self.breathHighColor
        breath.duration = 0.95
        breath.autoreverses = true
        breath.repeatCount = .infinity
        breath.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        memoryBackdrop.layer?.add(breath, forKey: "breath")
    }

    func stopLoadingAnimation() {
        memoryBackdrop.layer?.removeAnimation(forKey: "breath")
    }
}
