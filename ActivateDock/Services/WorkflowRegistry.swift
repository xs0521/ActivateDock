//
//  WorkflowRegistry.swift
//  ActivateDock
//
//  Keyword → Workflow index. Reloaded once at app launch (and whenever
//  PluginWatcher fires). Search routing consults `match(input:)` to
//  decide whether typed text addresses a plugin instead of the
//  installed-apps list.
//
//  Also retains diagnostics from the most recent reload —
//  `loadFailures` and `keywordConflicts` — so the Settings UI can
//  show users which plugins didn't load and which keywords collided.
//

import Foundation

final class WorkflowRegistry {
    static let shared = WorkflowRegistry()
    static let didReloadNotification = Notification.Name("WorkflowRegistry.didReload")

    private var byKeyword: [String: Workflow] = [:]
    private var declaredSecretsByBundle: [String: Set<String>] = [:]
    private(set) var loadFailures: [PluginLoadFailure] = []
    private(set) var keywordConflicts: [PluginKeywordConflict] = []

    private init() {}

    func reload() {
        let result = AlfredWorkflowLoader.loadAll(at: PluginPaths.root)
        loadFailures = result.failures

        var index: [String: Workflow] = [:]
        var droppedByKeyword: [String: [Workflow]] = [:]
        for w in result.workflows {
            let key = w.keyword.lowercased()
            if index[key] != nil {
                NSLog("[WorkflowRegistry] duplicate keyword \"\(key)\" — keeping first, dropping \(w.bundleId)")
                droppedByKeyword[key, default: []].append(w)
                continue
            }
            index[key] = w
        }
        keywordConflicts = droppedByKeyword.compactMap { kw, dropped in
            guard let kept = index[kw] else { return nil }
            return PluginKeywordConflict(keyword: kw, kept: kept, dropped: dropped)
        }.sorted { $0.keyword < $1.keyword }

        var secrets: [String: Set<String>] = [:]
        for w in result.workflows {
            secrets[w.bundleId, default: []].formUnion(w.declaredSecretVariables)
        }
        declaredSecretsByBundle = secrets

        byKeyword = index
        NSLog("[WorkflowRegistry] loaded \(byKeyword.count) workflow(s): \(byKeyword.keys.sorted())")
        NotificationCenter.default.post(name: Self.didReloadNotification, object: self)
    }

    func workflow(forKeyword keyword: String) -> Workflow? {
        byKeyword[keyword.lowercased()]
    }

    func match(input: String) -> (workflow: Workflow, query: String)? {
        guard let space = input.firstIndex(of: " ") else { return nil }
        let keyword = input[..<space].lowercased()
        guard let w = byKeyword[String(keyword)] else { return nil }
        // An empty query is intentional: Alfred fires the script filter
        // as soon as the keyword + a single space is typed, so plugins
        // can render initial state (recent items, defaults, etc).
        let query = input[input.index(after: space)...]
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (w, query)
    }

    var keywords: [String] {
        Array(byKeyword.keys).sorted()
    }

    var allWorkflows: [Workflow] {
        Array(byKeyword.values).sorted { $0.name < $1.name }
    }

    func declaredSecrets(forBundleId bundleId: String) -> Set<String> {
        declaredSecretsByBundle[bundleId] ?? []
    }
}
