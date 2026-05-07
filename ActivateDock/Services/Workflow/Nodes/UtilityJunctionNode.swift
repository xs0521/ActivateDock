//
//  UtilityJunctionNode.swift
//  ActivateDock
//
//  Pure pass-through node. Forwards the incoming arg and no new variables
//  (X5 decision: utility.junction is in MVP as a zero-cost pass-through).
//

import Foundation

final class UtilityJunctionNode: WorkflowNode {
    let uid: String
    let nodeType = "utility.junction"

    init(uid: String) { self.uid = uid }

    func execute(input: NodeInput, context: WorkflowContext,
                 completion: @escaping (Result<NodeOutput, WorkflowError>) -> Void) {
        completion(.success(.forward(arg: input.arg, variables: [:])))
    }
}
