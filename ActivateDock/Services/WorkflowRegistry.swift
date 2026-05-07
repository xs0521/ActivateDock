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

        var index: [String: IndexEntry] = [:]
        var droppedByKeyword: [String: [String]] = [:]
        for graph in result.graphs {
            for ep in graph.entrypoints {
                let key = ep.keyword.lowercased()
                if index[key] != nil {
                    NSLog("[WorkflowRegistry] duplicate keyword \"\(key)\" — keeping first, dropping \(graph.bundleId)")
                    droppedByKeyword[key, default: []].append(graph.bundleId)
                    continue
                }
                index[key] = (graph, ep)
            }
        }

        keywordConflicts = droppedByKeyword.compactMap { kw, dropped in
            guard let (keptGraph, _) = index[kw] else { return nil }
            return PluginKeywordConflict(keyword: kw,
                                         keptBundleId: keptGraph.bundleId,
                                         droppedBundleIds: dropped)
        }.sorted { $0.keyword < $1.keyword }

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
