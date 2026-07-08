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
//    - Secret values: locally encrypted UserDefaults values, account =
//      "<bundleId>::<varKey>". This avoids Keychain permission prompts.
//

import Foundation

final class PluginConfigStore {
    static let shared = PluginConfigStore()

    private let defaultsKey = "PluginConfigOverrides"
    private let keywordOwnerDefaultsKey = "PluginKeywordOwnerOverrides"
    private var nonSecretOverrides: [String: [String: String]] = [:]
    private var keywordOwnerOverrides: [String: String] = [:]

    private init() {
        load()
    }

    func override(for bundleId: String, varKey: String) -> String? {
        if PluginVariableSensitivity.isSecret(bundleId: bundleId, varKey: varKey) {
            return PluginSecretStore.read(account: secretAccount(bundleId: bundleId, varKey: varKey))
        }
        return nonSecretOverrides[bundleId]?[varKey]
    }

    func setOverride(_ value: String, for bundleId: String, varKey: String) {
        if PluginVariableSensitivity.isSecret(bundleId: bundleId, varKey: varKey) {
            let account = secretAccount(bundleId: bundleId, varKey: varKey)
            if value.isEmpty {
                PluginSecretStore.delete(account: account)
            } else {
                PluginSecretStore.write(value, account: account)
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

    func mergedVariables(for graph: WorkflowGraph) -> [String: String] {
        var merged = graph.variables
        for (k, _) in graph.variables {
            if let v = override(for: graph.bundleId, varKey: k) { merged[k] = v }
        }
        return merged
    }

    func preferredKeywordOwner(for keyword: String) -> String? {
        keywordOwnerOverrides[keyword.lowercased()]
    }

    func setPreferredKeywordOwner(_ bundleId: String, for keyword: String) {
        keywordOwnerOverrides[keyword.lowercased()] = bundleId
        saveKeywordOwners()
    }

    private func secretAccount(bundleId: String, varKey: String) -> String {
        "\(bundleId)::\(varKey)"
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode([String: [String: String]].self, from: data) else {
            nonSecretOverrides = [:]
            loadKeywordOwners()
            return
        }
        nonSecretOverrides = decoded
        loadKeywordOwners()
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(nonSecretOverrides) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }

    private func loadKeywordOwners() {
        guard let data = UserDefaults.standard.data(forKey: keywordOwnerDefaultsKey),
              let decoded = try? JSONDecoder().decode([String: String].self, from: data) else {
            keywordOwnerOverrides = [:]
            return
        }
        keywordOwnerOverrides = decoded
    }

    private func saveKeywordOwners() {
        guard let data = try? JSONEncoder().encode(keywordOwnerOverrides) else { return }
        UserDefaults.standard.set(data, forKey: keywordOwnerDefaultsKey)
    }
}
