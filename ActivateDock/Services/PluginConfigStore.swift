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
//  Storage: UserDefaults, JSON-encoded `[bundleId: [varKey: value]]`.
//  Credentials are stored as cleartext — Keychain upgrade is a follow-up
//  once we know which fields are sensitive.
//

import Foundation

final class PluginConfigStore {
    static let shared = PluginConfigStore()

    private let defaultsKey = "PluginConfigOverrides"
    private var overrides: [String: [String: String]] = [:]

    private init() { load() }

    func override(for bundleId: String, varKey: String) -> String? {
        overrides[bundleId]?[varKey]
    }

    func setOverride(_ value: String, for bundleId: String, varKey: String) {
        var bucket = overrides[bundleId] ?? [:]
        if value.isEmpty {
            bucket.removeValue(forKey: varKey)
        } else {
            bucket[varKey] = value
        }
        if bucket.isEmpty {
            overrides.removeValue(forKey: bundleId)
        } else {
            overrides[bundleId] = bucket
        }
        save()
    }

    func mergedVariables(for workflow: Workflow) -> [String: String] {
        var merged = workflow.variables
        if let userBucket = overrides[workflow.bundleId] {
            for (k, v) in userBucket { merged[k] = v }
        }
        return merged
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode([String: [String: String]].self, from: data) else {
            overrides = [:]
            return
        }
        overrides = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(overrides) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }
}
