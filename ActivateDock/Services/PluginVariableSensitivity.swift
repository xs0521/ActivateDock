//
//  PluginVariableSensitivity.swift
//  ActivateDock
//
//  Decides whether a plugin manifest variable is "sensitive"
//  (credential-bearing), so PluginConfigStore can route the value to
//  Keychain and the Settings UI can render it as a secure field.
//
//  Two signals, in priority order:
//    1. Explicit declaration — the manifest's optional
//       `secretvariables: [String]` field, surfaced via
//       WorkflowRegistry.declaredSecrets(forBundleId:). This is the
//       authoritative source when the plugin author opts in.
//    2. Name heuristic — substring/exact-match against conventional
//       credential keywords (key, secret, token, password, etc).
//       Alfred's stock schema has no native "isSecret" marker, so the
//       heuristic catches the typical cases when authors don't opt in.
//
//  False negatives just leave a value cleartext-in-UserDefaults; false
//  positives just hide a non-sensitive value. Plugins can avoid both
//  outcomes by listing the relevant variable names in
//  `secretvariables` themselves.
//

import Foundation

enum PluginVariableSensitivity {

    static func isSecret(bundleId: String, varKey: String) -> Bool {
        if WorkflowRegistry.shared.declaredSecrets(forBundleId: bundleId).contains(varKey) {
            return true
        }
        return matchesHeuristic(varKey: varKey)
    }

    private static func matchesHeuristic(varKey: String) -> Bool {
        let lower = varKey.lowercased()
        if exactMatches.contains(lower) { return true }
        return substringNeedles.contains(where: { lower.contains($0) })
    }

    private static let exactMatches: Set<String> = ["key", "pwd"]
    private static let substringNeedles: [String] = [
        "secret", "password", "token", "apikey", "appkey"
    ]
}
