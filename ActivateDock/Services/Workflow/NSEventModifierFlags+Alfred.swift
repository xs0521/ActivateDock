//
//  NSEventModifierFlags+Alfred.swift
//  ActivateDock
//
//  Conversions between NSEvent.ModifierFlags and Alfred's two modifier
//  representations:
//    - connections.modifiers  — Int bitmask  (1=cmd 2=alt 4=ctrl 8=shift 16=fn)
//    - item.mods dict key     — String       ("cmd" / "alt" / "cmd+shift" / …)
//

import AppKit

extension NSEvent.ModifierFlags {

    // Alfred connections.modifiers bitmask → ModifierFlags
    static func fromAlfredEdgeMask(_ mask: Int) -> Self {
        var f: NSEvent.ModifierFlags = []
        if mask & 1  != 0 { f.insert(.command) }
        if mask & 2  != 0 { f.insert(.option) }
        if mask & 4  != 0 { f.insert(.control) }
        if mask & 8  != 0 { f.insert(.shift) }
        if mask & 16 != 0 { f.insert(.function) }
        return f
    }

    // Alfred item.mods string key → ModifierFlags
    // Handles any "+" separated combination: "cmd+shift", "shift+cmd", etc.
    static func fromAlfredModKey(_ key: String) -> Self {
        let parts = key.split(separator: "+").map { $0.trimmingCharacters(in: .whitespaces) }
        var f: NSEvent.ModifierFlags = []
        for part in parts {
            switch part {
            case "cmd":   f.insert(.command)
            case "alt":   f.insert(.option)
            case "ctrl":  f.insert(.control)
            case "shift": f.insert(.shift)
            case "fn":    f.insert(.function)
            default:      break
            }
        }
        return f
    }

    // The flags actually relevant for Alfred mod matching (strips capsLock,
    // numericPad, etc. that the OS can sneak into modifierFlags).
    var alfredRelevant: NSEvent.ModifierFlags {
        intersection([.command, .option, .control, .shift])
    }
}
