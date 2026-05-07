//
//  WorkflowNode.swift
//  ActivateDock
//
//  Core protocol + shared types for the graph execution engine.
//  Every node type (input.scriptfilter, action.script, utility.junction …)
//  implements WorkflowNode. The executor calls execute() and follows the
//  output down the edge graph.
//

import AppKit
import Foundation

protocol WorkflowNode {
    var uid: String { get }
    var nodeType: String { get }
    func execute(input: NodeInput,
                 context: WorkflowContext,
                 completion: @escaping (Result<NodeOutput, WorkflowError>) -> Void)
}

// Implemented by input.* nodes that can be interrupted mid-flight.
// Action nodes detach and run to completion (X2 decision).
protocol CancellableNode: WorkflowNode {
    func cancel()
}

struct NodeInput {
    let arg: String?
    let modifiers: NSEvent.ModifierFlags
}

enum NodeOutput {
    case items([AlfredItem])
    case forward(arg: String?, variables: [String: String])
    case terminal
}

struct WorkflowError: Error {
    enum Kind {
        case nodeFailed(stderr: String, exitCode: Int32)
        case decodeFailed(raw: String, underlying: Error)
        case launchFailed(Error)
        case missingNode(uid: String)
        case unsupportedNodeType(String)
    }
    let kind: Kind
    let nodeUID: String?
    let nodeType: String?
}

enum UIIntent {
    case showLoading
    case showItems([AlfredItem])
    case showError(WorkflowError)
    case dismissAndPerform
}

protocol Cancellable: AnyObject {
    func cancel()
}
