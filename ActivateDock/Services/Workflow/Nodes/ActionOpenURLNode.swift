//
//  ActionOpenURLNode.swift
//  ActivateDock
//
//  Opens the resolved URL using NSWorkspace. Runs on the main thread
//  (NSWorkspace requirement), then returns .terminal.
//

import AppKit

final class ActionOpenURLNode: WorkflowNode {
    let uid: String
    let nodeType = "action.openurl"
    private let urlTemplate: String

    init(uid: String, urlTemplate: String) {
        self.uid = uid
        self.urlTemplate = urlTemplate
    }

    func execute(input: NodeInput, context: WorkflowContext,
                 completion: @escaping (Result<NodeOutput, WorkflowError>) -> Void) {
        let resolved = urlTemplate.replacingOccurrences(of: "{query}", with: input.arg ?? "")
        DispatchQueue.main.async {
            if let url = URL(string: resolved) { NSWorkspace.shared.open(url) }
            completion(.success(.terminal))
        }
    }
}
