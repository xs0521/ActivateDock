//
//  WorkflowRegistry.swift
//  ActivateDock
//
//  Keyword → (WorkflowGraph, Entrypoint) index. Reloaded at app launch
//  and whenever PluginWatcher fires. Search routing calls match(input:)
//  to decide whether typed text addresses a plugin entry node.
//
//  allGraphs is the de-duplicated-by-bundleId list used by Settings UI.
//  loadFailures and keywordConflicts surface loader diagnostics to users.
//

import Foundation

final class WorkflowRegistry {
    static let shared = WorkflowRegistry()
    static let didReloadNotification = Notification.Name("WorkflowRegistry.didReload")

    private typealias IndexEntry = (graph: WorkflowGraph, entrypoint: WorkflowGraph.Entrypoint)
    private var byKeyword: [String: IndexEntry] = [:]
    private var graphsByBundle: [String: WorkflowGraph] = [:]
    private var declaredSecretsByBundle: [String: Set<String>] = [:]
    private(set) var loadFailures: [PluginLoadFailure] = []
    private(set) var keywordConflicts: [PluginKeywordConflict] = []

    private init() {}

    func reload() {
        let result = AlfredWorkflowLoader.loadAll(at: PluginPaths.root)
        loadFailures = result.failures

        var candidates: [String: [IndexEntry]] = [:]
        for graph in result.graphs {
            for ep in graph.entrypoints {
                let key = ep.keyword.lowercased()
                candidates[key, default: []].append((graph, ep))
            }
        }

        var index: [String: IndexEntry] = [:]
        var conflicts: [PluginKeywordConflict] = []
        for (keyword, entries) in candidates {
            let preferred = PluginConfigStore.shared.preferredKeywordOwner(for: keyword)
            let selected = entries.first { $0.graph.bundleId == preferred } ?? entries[0]
            index[keyword] = selected

            guard entries.count > 1 else { continue }
            let ids = entries.map { $0.graph.bundleId }
            conflicts.append(PluginKeywordConflict(
                keyword: keyword,
                selectedBundleId: selected.graph.bundleId,
                candidateBundleIds: ids
            ))
            let ignored = ids.filter { $0 != selected.graph.bundleId }
            NSLog("[WorkflowRegistry] duplicate keyword \"\(keyword)\" — keeping \(selected.graph.bundleId), dropping \(ignored)")
        }
        keywordConflicts = conflicts.sorted { $0.keyword < $1.keyword }

        var bundles: [String: WorkflowGraph] = [:]
        var secrets: [String: Set<String>] = [:]
        for graph in result.graphs {
            bundles[graph.bundleId] = graph
            secrets[graph.bundleId, default: []].formUnion(graph.declaredSecretVariables)
        }

        byKeyword = index
        graphsByBundle = bundles
        declaredSecretsByBundle = secrets

        NSLog("[WorkflowRegistry] loaded \(byKeyword.count) entrypoint(s): \(byKeyword.keys.sorted())")
        NotificationCenter.default.post(name: Self.didReloadNotification, object: self)
    }

    func graph(forKeyword keyword: String) -> WorkflowGraph? {
        byKeyword[keyword.lowercased()]?.graph
    }

    func entrypoint(forKeyword keyword: String) -> WorkflowGraph.Entrypoint? {
        byKeyword[keyword.lowercased()]?.entrypoint
    }

    func match(input: String) -> (graph: WorkflowGraph, entrypoint: WorkflowGraph.Entrypoint, query: String)? {
        let exact = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let entry = byKeyword[exact] {
            return (entry.graph, entry.entrypoint, "")
        }
        guard let space = input.firstIndex(of: " ") else { return nil }
        let keyword = input[..<space].lowercased()
        guard let entry = byKeyword[String(keyword)] else { return nil }
        let query = input[input.index(after: space)...]
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (entry.graph, entry.entrypoint, query)
    }

    var allGraphs: [WorkflowGraph] {
        Array(graphsByBundle.values).sorted { $0.name < $1.name }
    }

    func declaredSecrets(forBundleId bundleId: String) -> Set<String> {
        declaredSecretsByBundle[bundleId] ?? []
    }
}
