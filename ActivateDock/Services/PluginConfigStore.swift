//
//  PluginConfigStore.swift
//  ActivateDock
//
//  Persists user-supplied values for plugin manifest variables. The
//  manifest's variables dict holds *defaults* (often placeholders like
//  "YOUR_API_KEY"); whatever the user types into Settings gets written
//  here and is merged on top of the defaults right before the Script
//  Filter runs.
//
//  Storage is split by sensitivity:
//    - Non-secret values: UserDefaults JSON `[bundleId: [varKey: value]]`.
//    - Secret values (heuristic via PluginVariableSensitivity.isSecret):
//      Keychain Services, account = "<bundleId>::<varKey>".
//

import Foundation

final class PluginConfigStore {
    static let shared = PluginConfigStore()

    private let defaultsKey = "PluginConfigOverrides"
    private var nonSecretOverrides: [String: [String: String]] = [:]

    private init() {
        load()
    }

    func override(for bundleId: String, varKey: String) -> String? {
        if PluginVariableSensitivity.isSecret(varKey: varKey) {
            return Keychain.read(account: keychainAccount(bundleId: bundleId, varKey: varKey))
        }
        return nonSecretOverrides[bundleId]?[varKey]
    }

    func setOverride(_ value: String, for bundleId: String, varKey: String) {
        if PluginVariableSensitivity.isSecret(varKey: varKey) {
            let account = keychainAccount(bundleId: bundleId, varKey: varKey)
            if value.isEmpty {
                Keychain.delete(account: account)
            } else {
                Keychain.write(value, account: account)
            }
            return
        }

        var bucket = nonSecretOverrides[bundleId] ?? [:]
        if value.isEmpty {
            bucket.removeValue(forKey: varKey)
        } else {
            bucket[varKey] = value
        }
        if bucket.isEmpty {
            nonSecretOverrides.removeValue(forKey: bundleId)
        } else {
            nonSecretOverrides[bundleId] = bucket
        }
        save()
    }

    func mergedVariables(for workflow: Workflow) -> [String: String] {
        var merged = workflow.variables
        for (k, _) in workflow.variables {
            if let v = override(for: workflow.bundleId, varKey: k) { merged[k] = v }
        }
        return merged
    }

    private func keychainAccount(bundleId: String, varKey: String) -> String {
        "\(bundleId)::\(varKey)"
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode([String: [String: String]].self, from: data) else {
            nonSecretOverrides = [:]
            return
        }
        nonSecretOverrides = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(nonSecretOverrides) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }
}
