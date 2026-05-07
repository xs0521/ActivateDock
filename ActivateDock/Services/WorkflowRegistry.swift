//
//  WorkflowRegistry.swift
//  ActivateDock
//
//  Keyword → Workflow index. Reloaded once at app launch. Search routing
//  consults `match(input:)` to decide whether typed text addresses a
//  plugin instead of the installed-apps list.
//

import Foundation

final class WorkflowRegistry {
    static let shared = WorkflowRegistry()
    static let didReloadNotification = Notification.Name("WorkflowRegistry.didReload")

    private var byKeyword: [String: Workflow] = [:]

    private init() {}

    func reload() {
        let workflows = AlfredWorkflowLoader.loadAll(at: PluginPaths.root)
        var index: [String: Workflow] = [:]
        for w in workflows {
            let key = w.keyword.lowercased()
            if index[key] != nil {
                NSLog("[WorkflowRegistry] duplicate keyword \"\(key)\" — keeping first, dropping \(w.bundleId)")
                continue
            }
            index[key] = w
        }
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
        let query = input[input.index(after: space)...]
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return nil }
        return (w, query)
    }

    var keywords: [String] {
        Array(byKeyword.keys).sorted()
    }

    var allWorkflows: [Workflow] {
        Array(byKeyword.values).sorted { $0.name < $1.name }
    }
}
