//
//  ActionScriptNode.swift
//  ActivateDock
//
//  Runs a shell script as a fire-and-forget action (X2 decision).
//  Stdout is discarded; stderr is logged. Always returns .terminal —
//  non-zero exit and launch errors are also terminal (no UI feedback).
//

import Foundation

final class ActionScriptNode: WorkflowNode {
    let uid: String
    let nodeType = "action.script"
    private let bundleId: String
    private let scriptCommand: String
    private let scriptLanguageType: Int?

    init(uid: String, bundleId: String, scriptCommand: String, scriptLanguageType: Int?) {
        self.uid = uid
        self.bundleId = bundleId
        self.scriptCommand = scriptCommand
        self.scriptLanguageType = scriptLanguageType
    }

    func execute(input: NodeInput, context: WorkflowContext,
                 completion: @escaping (Result<NodeOutput, WorkflowError>) -> Void) {
        let body = shellSubstitute(scriptCommand, query: input.arg ?? "")
        let plan: ScriptInvocation.Plan
        do {
            plan = try ScriptInvocation.plan(body: body,
                                             scriptLanguageType: scriptLanguageType,
                                             bundleId: bundleId)
        } catch {
            let e = WorkflowError(kind: .launchFailed(error), nodeUID: uid, nodeType: nodeType)
            DispatchQueue.main.async { completion(.failure(e)) }
            return
        }

        let process = Process()
        process.executableURL        = plan.executable
        process.arguments            = plan.arguments
        process.currentDirectoryURL  = context.graph.pluginDirectory

        var env = ProcessInfo.processInfo.environment
        for (k, v) in context.variables { env[k] = v }
        process.environment = env

        let logTag  = "[plugin:\(bundleId)]"
        let errPipe = Pipe(), outPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError  = errPipe

        errPipe.fileHandleForReading.readabilityHandler = { h in
            let chunk = h.availableData
            guard !chunk.isEmpty else { return }
            if let t = String(data: chunk, encoding: .utf8) {
                let s = t.trimmingCharacters(in: .whitespacesAndNewlines)
                if !s.isEmpty { NSLog("\(logTag) \(s)") }
            }
        }
        outPipe.fileHandleForReading.readabilityHandler = { h in _ = h.availableData }

        process.terminationHandler = { _ in
            errPipe.fileHandleForReading.readabilityHandler = nil
            outPipe.fileHandleForReading.readabilityHandler = nil
            if let url = plan.cleanupURL { try? FileManager.default.removeItem(at: url) }
            DispatchQueue.main.async { completion(.success(.terminal)) }
        }

        do {
            try process.run()
        } catch {
            if let url = plan.cleanupURL { try? FileManager.default.removeItem(at: url) }
            let e = WorkflowError(kind: .launchFailed(error), nodeUID: uid, nodeType: nodeType)
            DispatchQueue.main.async { completion(.failure(e)) }
        }
    }

    private func shellSubstitute(_ template: String, query: String) -> String {
        let quoted = "'" + query.replacingOccurrences(of: "'", with: "'\\''") + "'"
        return template.replacingOccurrences(of: "{query}", with: quoted)
    }
}
