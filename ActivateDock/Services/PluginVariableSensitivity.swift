//
//  PluginVariableSensitivity.swift
//  ActivateDock
//
//  Heuristic that classifies a plugin manifest variable name as
//  "sensitive" (credential-bearing) so PluginConfigStore can route it
//  to Keychain and the Settings UI can render it as a secure field.
//
//  Alfred's manifest schema has no native "isSecret" marker. Plugin
//  authors conventionally name credential vars `key`, `secret`,
//  `token`, `password`, etc. — this matches that convention. False
//  negatives just leave a value cleartext-in-UserDefaults; false
//  positives just hide a non-sensitive value.
//

import Foundation

enum PluginVariableSensitivity {

    static func isSecret(varKey: String) -> Bool {
        let lower = varKey.lowercased()
        if exactMatches.contains(lower) { return true }
        return substringNeedles.contains(where: { lower.contains($0) })
    }

    private static let exactMatches: Set<String> = ["key", "pwd"]
    private static let substringNeedles: [String] = [
        "secret", "password", "token", "apikey", "appkey"
    ]
}
