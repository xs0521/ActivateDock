//
//  HotKeyManager.swift
//  ActivateDock
//

import Carbon.HIToolbox
import Cocoa

final class HotKeyManager {
    static let shared = HotKeyManager()

    var onTrigger: (() -> Void)?
    private(set) var currentCombo: HotKeyCombo = .default

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private static let signature: OSType = 0x41444B4B  // "ADKK"

    private init() {}

    func register() {
        register(combo: HotKeyCombo.loadStored())
    }

    @discardableResult
    func register(combo: HotKeyCombo) -> Bool {
        installEventHandler()
        currentCombo = combo
        return registerCombo(keyCode: combo.keyCode, modifiers: combo.modifiers)
    }

    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }
    }

    private func installEventHandler() {
        guard eventHandler == nil else { return }
        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, _ -> OSStatus in
                DispatchQueue.main.async {
                    HotKeyManager.shared.onTrigger?()
                }
                return noErr
            },
            1,
            &spec,
            nil,
            &eventHandler
        )
    }

    @discardableResult
    private func registerCombo(keyCode: UInt32, modifiers: UInt32) -> Bool {
        if let existing = hotKeyRef {
            UnregisterEventHotKey(existing)
            hotKeyRef = nil
        }
        let id = EventHotKeyID(signature: Self.signature, id: 1)
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            id,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        if status != noErr {
            NSLog("[HotKey] register failed: %d", status)
            return false
        }
        return true
    }
}
