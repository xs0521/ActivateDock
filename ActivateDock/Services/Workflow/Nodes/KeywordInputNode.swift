//
//  KeywordInputNode.swift
//  ActivateDock
//
//  Alfred `input.keyword` node. Presents itself as a single selectable item
//  so the user can confirm intent by pressing Enter. The executor then follows
//  the graph edge to the downstream action node (activate() path, X2 decision).
//  No script is executed at this stage — the arg is the user's raw query.
//

import Foundation

struct KeywordInputNode: WorkflowNode {
    let uid: String
    let nodeType = "input.keyword"
    let title: String
    let subtitle: String?

    func execute(input: NodeInput,
                 context: WorkflowContext,
                 completion: @escaping (Result<NodeOutput, WorkflowError>) -> Void) {
        let item = AlfredItem(title: title, subtitle: subtitle,
                              arg: input.arg, icon: nil,
                              mods: nil, variables: nil, valid: nil)
        completion(.success(.items([item])))
    }
}
