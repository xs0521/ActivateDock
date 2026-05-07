//
//  AlfredItem.swift
//  ActivateDock
//

import Foundation

struct AlfredIcon: Decodable {
    let path: String?
}

// Per-modifier-key override a scriptfilter item can carry.
// When the user presses ↩ + modifier X, the engine looks up item.mods[X]
// and substitutes arg/subtitle/variables from the matching entry.
struct AlfredItemMod: Decodable {
    let arg: String?
    let subtitle: String?
    let valid: Bool?
    let variables: [String: String]?
}

struct AlfredItem: Decodable {
    let title: String
    let subtitle: String?
    let arg: String?
    let icon: AlfredIcon?
    // Modifier-key overrides — key is Alfred's string ("cmd" / "alt" / "cmd+shift" / …)
    let mods: [String: AlfredItemMod]?
    // Variables injected into context when this item is selected
    let variables: [String: String]?
    // false = item is disabled; Enter doesn't respond, cell is greyed out
    let valid: Bool?
}

struct AlfredScriptFilterOutput: Decodable {
    let items: [AlfredItem]
}
