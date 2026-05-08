//
//  ScriptFilterNode.swift
//  ActivateDock
//
//  WorkflowNode implementation for alfred.workflow.input.scriptfilter.
//  Each execute() call spawns a fresh Process (X1 decision). Mirrors the
//  pipe-draining and stderr-logging strategy from AlfredScriptFilterRunner,
//  but produces NodeOutput / WorkflowError instead of AlfredRunnerError.
//

import Foundation

final class ScriptFilterNode: CancellableNode {

    let uid: String
    let nodeType = "input.scriptfilter"

    private let bundleId: String
    private let name: String
    private let scriptCommand: String
    private let scriptLanguageType: Int?

    private let lock = NSLock()
    private var inflightProcess: Process?
    private var requestSeq = 0

    init(uid: String, bundleId: String, name: String,
         scriptCommand: String, scriptLanguageType: Int?) {
        self.uid = uid
        self.bundleId = bundleId
        self.name = name
        self.scriptCommand = scriptCommand
        self.scriptLanguageType = scriptLanguageType
    }

    func execute(input: NodeInput,
                 context: WorkflowContext,
                 completion: @escaping (Result<NodeOutput, WorkflowError>) -> Void) {
        lock.lock()
        requestSeq += 1
        let mySeq = requestSeq
        inflightProcess?.terminate()
        let process = Process()
        inflightProcess = process
        lock.unlock()

        let query = input.arg ?? ""
        let body = ScriptInvocation.substituteQuery(in: scriptCommand, query: query)

        let plan: ScriptInvocation.Plan
        do {
            plan = try ScriptInvocation.plan(body: body,
                                             scriptLanguageType: scriptLanguageType,
                                             bundleId: bundleId)
        } catch {
            lock.lock(); if inflightProcess === process { inflightProcess = nil }; lock.unlock()
            let e = WorkflowError(kind: .launchFailed(error), nodeUID: uid, nodeType: nodeType)
            DispatchQueue.main.async { completion(.failure(e)) }
            return
        }

        process.executableURL = plan.executable
        process.arguments    = plan.arguments
        process.currentDirectoryURL = context.graph.pluginDirectory

        var env = ProcessInfo.processInfo.environment
        for (k, v) in context.variables { env[k] = v }
        process.environment = env

        let logTag     = "[plugin:\(bundleId)]"
        let errPipe    = Pipe(), outPipe = Pipe()
        let stderrLock = NSLock(), stdoutLock = NSLock()
        var stderrBuf  = Data(), stdoutBuf = Data()

        errPipe.fileHandleForReading.readabilityHandler = { h in
            let chunk = h.availableData
            guard !chunk.isEmpty else { return }
            stderrLock.lock(); stderrBuf.append(chunk); stderrLock.unlock()
            if let t = String(data: chunk, encoding: .utf8) {
                let s = t.trimmingCharacters(in: .whitespacesAndNewlines)
                if !s.isEmpty { NSLog("\(logTag) \(s)") }
            }
        }
        outPipe.fileHandleForReading.readabilityHandler = { h in
            let chunk = h.availableData
            guard !chunk.isEmpty else { return }
            stdoutLock.lock(); stdoutBuf.append(chunk); stdoutLock.unlock()
        }

        process.standardOutput = outPipe
        process.standardError  = errPipe

        let pluginDir = context.graph.pluginDirectory
        process.terminationHandler = { [weak self] proc in
            guard let self else { return }

            self.lock.lock()
            let isLatest = mySeq == self.requestSeq
            if isLatest { self.inflightProcess = nil }
            self.lock.unlock()

            if let url = plan.cleanupURL { try? FileManager.default.removeItem(at: url) }

            errPipe.fileHandleForReading.readabilityHandler = nil
            stderrLock.lock()
            stderrBuf.append(errPipe.fileHandleForReading.availableData)
            let errStr = String(data: stderrBuf, encoding: .utf8) ?? ""
            stderrLock.unlock()

            outPipe.fileHandleForReading.readabilityHandler = nil
            stdoutLock.lock()
            stdoutBuf.append(outPipe.fileHandleForReading.availableData)
            let outData = stdoutBuf
            stdoutLock.unlock()

            guard isLatest else { return }

            if proc.terminationStatus != 0 {
                let e = WorkflowError(kind: .nodeFailed(stderr: errStr, exitCode: proc.terminationStatus),
                                      nodeUID: self.uid, nodeType: self.nodeType)
                DispatchQueue.main.async { completion(.failure(e)) }
                return
            }

            do {
                let parsed = try JSONDecoder().decode(AlfredScriptFilterOutput.self, from: outData)
                let resolved = parsed.items.map { item -> AlfredItem in
                    guard let path = item.icon?.path, !path.isEmpty, !path.hasPrefix("/") else { return item }
                    let abs = pluginDir.appendingPathComponent(path).path
                    return AlfredItem(title: item.title, subtitle: item.subtitle,
                                      arg: item.arg, icon: AlfredIcon(path: abs),
                                      mods: item.mods, variables: item.variables, valid: item.valid)
                }
                DispatchQueue.main.async { completion(.success(.items(resolved))) }
            } catch {
                let raw = String(data: outData, encoding: .utf8) ?? ""
                let e = WorkflowError(kind: .decodeFailed(raw: raw, underlying: error),
                                      nodeUID: self.uid, nodeType: self.nodeType)
                DispatchQueue.main.async { completion(.failure(e)) }
            }
        }

        do {
            try process.run()
        } catch {
            lock.lock(); if inflightProcess === process { inflightProcess = nil }; lock.unlock()
            if let url = plan.cleanupURL { try? FileManager.default.removeItem(at: url) }
            let e = WorkflowError(kind: .launchFailed(error), nodeUID: uid, nodeType: nodeType)
            DispatchQueue.main.async { completion(.failure(e)) }
        }
    }

    func cancel() {
        lock.lock()
        requestSeq += 1
        inflightProcess?.terminate()
        inflightProcess = nil
        lock.unlock()
    }
}
