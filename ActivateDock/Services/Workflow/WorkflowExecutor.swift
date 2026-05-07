//
//  WorkflowExecutor.swift
//  ActivateDock
//
//  Drives a single walk through a WorkflowGraph. Emits UIIntent values
//  to the caller so the UI layer never needs to understand node types.
//
//  Cancellation (X2):
//    - enter() / cancelCurrent() interrupt input.* nodes via CancellableNode.
//    - activate() emits dismissAndPerform synchronously, then walks action
//      nodes in the background — they run to completion regardless.
//

import AppKit
import Foundation

final class WorkflowExecutor {

    private let lock = NSLock()
    private var currentToken: ExecutorToken?
    private var currentContext: WorkflowContext?
    private var currentNodeUID: String?
    private var intentHandler: ((UIIntent) -> Void)?

    @discardableResult
    func enter(graph: WorkflowGraph,
               entry: any WorkflowNode,
               query: String,
               modifiers: NSEvent.ModifierFlags = [],
               variables: [String: String],
               intentHandler: @escaping (UIIntent) -> Void) -> any Cancellable {
        lock.lock()
        currentToken?.performCancel()
        let token = ExecutorToken()
        currentToken = token
        currentContext = nil
        currentNodeUID = nil
        self.intentHandler = intentHandler
        lock.unlock()

        intentHandler(.showLoading)
        let ctx = WorkflowContext(graph: graph, bundleId: graph.bundleId, variables: variables)
        walk(from: entry, arg: query.isEmpty ? nil : query, modifiers: modifiers,
             ctx: ctx, token: token, intentHandler: intentHandler)
        return token
    }

    // Returns true if a downstream edge was found and activated.
    // Emits dismissAndPerform synchronously before launching the action.
    // Returns false → caller should fall back to URL-open/copy.
    func activate(item: AlfredItem, modifiers: NSEvent.ModifierFlags) -> Bool {
        lock.lock()
        let fromUID = currentNodeUID
        let ctx = currentContext
        let hasToken = currentToken != nil
        let handler = intentHandler
        lock.unlock()

        guard hasToken, let fromUID, let ctx, let handler else { return false }
        let edges = ctx.graph.edges[fromUID] ?? []
        guard !edges.isEmpty else { return false }

        let edge = edges.first(where: { $0.modifiers == modifiers })
            ?? edges.first(where: { $0.modifiers == [] })
        guard let edge, let destNode = ctx.graph.nodes[edge.destination] else { return false }

        // Merge item-level variables into context before action runs (A7)
        if let vars = item.variables { for (k, v) in vars { ctx.variables[k] = v } }

        // X2: dismiss before action — handler may call cancelCurrent() internally, which is fine
        handler(.dismissAndPerform)

        lock.lock()
        let bgToken = ExecutorToken()
        currentToken = bgToken
        currentContext = nil
        currentNodeUID = nil
        lock.unlock()

        walk(from: destNode, arg: item.arg, modifiers: [],
             ctx: ctx, token: bgToken, intentHandler: { _ in })
        return true
    }

    func cancelCurrent() {
        lock.lock()
        currentToken?.performCancel()
        currentToken = nil
        currentContext = nil
        currentNodeUID = nil
        intentHandler = nil
        lock.unlock()
    }

    private func walk(from node: any WorkflowNode,
                      arg: String?,
                      modifiers: NSEvent.ModifierFlags,
                      ctx: WorkflowContext,
                      token: ExecutorToken,
                      intentHandler: @escaping (UIIntent) -> Void) {
        if let cn = node as? CancellableNode {
            lock.lock()
            if currentToken === token { token.onCancel = { cn.cancel() } }
            lock.unlock()
        }
        node.execute(input: NodeInput(arg: arg, modifiers: modifiers), context: ctx) { [weak self] result in
            guard let self else { return }
            self.lock.lock()
            let isCurrent = self.currentToken === token
            self.lock.unlock()
            guard isCurrent else { return }

            switch result {
            case .success(let output):
                switch output {
                case .items(let items):
                    self.lock.lock()
                    self.currentNodeUID = node.uid
                    self.currentContext = ctx
                    self.lock.unlock()
                    intentHandler(.showItems(items))
                case .forward(let nextArg, let vars):
                    for (k, v) in vars { ctx.variables[k] = v }
                    self.continueWalk(fromUID: node.uid, arg: nextArg,
                                      ctx: ctx, token: token, intentHandler: intentHandler)
                case .terminal:
                    intentHandler(.dismissAndPerform)
                }
            case .failure(let err):
                intentHandler(.showError(err))
            }
        }
    }

    private func continueWalk(fromUID: String,
                               arg: String?,
                               ctx: WorkflowContext,
                               token: ExecutorToken,
                               intentHandler: @escaping (UIIntent) -> Void) {
        let edges = ctx.graph.edges[fromUID] ?? []
        guard let edge = edges.first(where: { $0.modifiers == [] }) ?? edges.first else {
            intentHandler(.dismissAndPerform)
            return
        }
        guard let next = ctx.graph.nodes[edge.destination] else {
            let err = WorkflowError(kind: .missingNode(uid: edge.destination),
                                    nodeUID: nil, nodeType: nil)
            intentHandler(.showError(err))
            return
        }
        if next is ScriptFilterNode {
            let err = WorkflowError(kind: .unsupportedNodeType("scriptfilter→scriptfilter chain"),
                                    nodeUID: next.uid, nodeType: next.nodeType)
            intentHandler(.showError(err))
            return
        }
        walk(from: next, arg: arg, modifiers: [], ctx: ctx, token: token, intentHandler: intentHandler)
    }
}

private final class ExecutorToken: Cancellable {
    private let lock = NSLock()
    var onCancel: (() -> Void)?

    func cancel() {
        lock.lock()
        let handler = onCancel
        lock.unlock()
        handler?()
    }

    func performCancel() { cancel() }
}
