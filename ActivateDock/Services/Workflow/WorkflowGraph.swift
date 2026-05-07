//
//  WorkflowGraph.swift
//  ActivateDock
//
//  Immutable graph loaded from a plugin's info.plist. Each Alfred workflow
//  bundle becomes one WorkflowGraph; its scriptfilter / keyword / action
//  objects become WorkflowNode values keyed by their plist UIDs.
//

import AppKit
import Foundation

struct WorkflowGraph {
    let bundleId: String
    let name: String
    let description: String?
    let pluginDirectory: URL
    let nodes: [String: any WorkflowNode]
    let edges: [String: [Edge]]
    let entrypoints: [Entrypoint]
    let variables: [String: String]
    let declaredSecretVariables: Set<String>

    struct Edge {
        let destination: String
        let modifiers: NSEvent.ModifierFlags
    }

    struct Entrypoint {
        let keyword: String
        let nodeUID: String
    }
}
