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

    // Custom decoder: `arg` can be a plain string or a JSON object (e.g.
    // {"url": "...", "title": "..."} — Safari Control cmd+shift mod).
    // If it isn't a string we silently drop it rather than failing the whole decode.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        arg       = try? c.decodeIfPresent(String.self, forKey: .arg)
        subtitle  = try  c.decodeIfPresent(String.self, forKey: .subtitle)
        valid     = try  c.decodeIfPresent(Bool.self,   forKey: .valid)
        variables = try  c.decodeIfPresent([String: String].self, forKey: .variables)
    }

    private enum CodingKeys: String, CodingKey {
        case arg, subtitle, valid, variables
    }
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
