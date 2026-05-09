//
//  UtilityArgumentNode.swift
//  ActivateDock
//
//  Alfred `utility.argument` node. It sets or passes through the current arg,
//  then lets the executor continue walking the graph.
//

import Foundation

struct UtilityArgumentNode: WorkflowNode {
    let uid: String
    let nodeType = "utility.argument"
    private let argumentTemplate: String
    private let passthrough: Bool

    init(uid: String, argumentTemplate: String, passthrough: Bool) {
        self.uid = uid
        self.argumentTemplate = argumentTemplate
        self.passthrough = passthrough
    }

    func execute(input: NodeInput,
                 context: WorkflowContext,
                 completion: @escaping (Result<NodeOutput, WorkflowError>) -> Void) {
        if passthrough {
            completion(.success(.forward(arg: input.arg, variables: [:])))
            return
        }
        let resolved = argumentTemplate
            .replacingOccurrences(of: "{query}", with: input.arg ?? "")
        completion(.success(.forward(arg: resolved, variables: [:])))
    }
}
