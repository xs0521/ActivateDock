//
//  HotKeyCombo.swift
//  ActivateDock
//

import Carbon.HIToolbox
import Cocoa

struct HotKeyCombo: Codable, Equatable {
    let keyCode: UInt32
    let modifiers: UInt32        // Carbon modifier flags
    let displayChar: String      // captured at recording time

    static let `default` = HotKeyCombo(
        keyCode: UInt32(kVK_Space),
        modifiers: UInt32(optionKey),
        displayChar: "Space"
    )

    var displayString: String {
        var s = ""
        if modifiers & UInt32(controlKey) != 0 { s += "⌃" }
        if modifiers & UInt32(optionKey)  != 0 { s += "⌥" }
        if modifiers & UInt32(shiftKey)   != 0 { s += "⇧" }
        if modifiers & UInt32(cmdKey)     != 0 { s += "⌘" }
        s += displayChar
        return s
    }

    static func carbonFlags(from cocoa: NSEvent.ModifierFlags) -> UInt32 {
        var f: UInt32 = 0
        if cocoa.contains(.command) { f |= UInt32(cmdKey) }
        if cocoa.contains(.option)  { f |= UInt32(optionKey) }
        if cocoa.contains(.control) { f |= UInt32(controlKey) }
        if cocoa.contains(.shift)   { f |= UInt32(shiftKey) }
        return f
    }

    static func displayChar(for event: NSEvent) -> String {
        switch Int(event.keyCode) {
        case kVK_Space:      return "Space"
        case kVK_Return:     return "↩"
        case kVK_Tab:        return "⇥"
        case kVK_Escape:     return "⎋"
        case kVK_Delete:     return "⌫"
        case kVK_ForwardDelete: return "⌦"
        case kVK_LeftArrow:  return "←"
        case kVK_RightArrow: return "→"
        case kVK_UpArrow:    return "↑"
        case kVK_DownArrow:  return "↓"
        case kVK_F1:  return "F1"
        case kVK_F2:  return "F2"
        case kVK_F3:  return "F3"
        case kVK_F4:  return "F4"
        case kVK_F5:  return "F5"
        case kVK_F6:  return "F6"
        case kVK_F7:  return "F7"
        case kVK_F8:  return "F8"
        case kVK_F9:  return "F9"
        case kVK_F10: return "F10"
        case kVK_F11: return "F11"
        case kVK_F12: return "F12"
        default:
            if let c = event.charactersIgnoringModifiers, !c.isEmpty {
                return c.uppercased()
            }
            return "?"
        }
    }
}

extension HotKeyCombo {
    private static let defaultsKey = "ActivationHotKey"

    static func loadStored() -> HotKeyCombo {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let combo = try? JSONDecoder().decode(HotKeyCombo.self, from: data) else {
            return .default
        }
        return combo
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.defaultsKey)
        }
    }
}
