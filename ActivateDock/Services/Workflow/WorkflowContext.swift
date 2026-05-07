//
//  WorkflowContext.swift
//  ActivateDock
//
//  Mutable state threaded through one executor walk. Starts from the
//  merged plugin variables (manifest defaults + user overrides) and
//  accumulates variable updates as nodes emit .forward(variables:).
//

import Foundation

final class WorkflowContext {
    let graph: WorkflowGraph
    let bundleId: String
    var variables: [String: String]

    init(graph: WorkflowGraph, bundleId: String, variables: [String: String]) {
        self.graph = graph
        self.bundleId = bundleId
        self.variables = variables
    }
}
