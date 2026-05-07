//
//  AlfredScriptFilterRunner.swift
//  ActivateDock
//
//  Spawns an Alfred-compatible Script Filter (any binary that prints
//  `{ "items": [...] }` to stdout) and decodes the result. Cancels any
//  prior in-flight invocation when a new one arrives.
//
//  The actual command is taken from a Workflow value (loaded from a
//  plugin's info.plist). Runner itself has no per-plugin state.
//

import Foundation

enum AlfredRunnerError: Error {
    case launchFailed(Error)
    case nonZeroExit(code: Int32, stderr: String)
    case decodeFailed(Error, raw: String)
    case cancelled
}

final class AlfredScriptFilterRunner {

    private let lock = NSLock()
    private var inflight: Process?
    private var requestSeq: Int = 0

    func run(workflow: Workflow,
             query: String,
             completion: @escaping (Result<[AlfredItem], AlfredRunnerError>) -> Void) {

        lock.lock()
        requestSeq += 1
        let mySeq = requestSeq
        inflight?.terminate()
        let process = Process()
        inflight = process
        lock.unlock()

        let plan: ScriptInvocation.Plan
        do {
            plan = try ScriptInvocation.plan(for: workflow, query: query)
        } catch {
            lock.lock()
            if inflight === process { inflight = nil }
            lock.unlock()
            DispatchQueue.main.async { completion(.failure(.launchFailed(error))) }
            return
        }
        process.executableURL = plan.executable
        process.arguments = plan.arguments
        process.currentDirectoryURL = workflow.directory

        var mergedEnv = ProcessInfo.processInfo.environment
        for (k, v) in PluginConfigStore.shared.mergedVariables(for: workflow) {
            mergedEnv[k] = v
        }
        process.environment = mergedEnv

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        let stderrLock = NSLock()
        var stderrBuffer = Data()
        let logTag = "[plugin:\(workflow.bundleId)]"
        errPipe.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            guard !chunk.isEmpty else { return }
            stderrLock.lock()
            stderrBuffer.append(chunk)
            stderrLock.unlock()
            if let text = String(data: chunk, encoding: .utf8) {
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { NSLog("\(logTag) \(trimmed)") }
            }
        }

        // Drain stdout the same way. Pipes have a ~16KB OS buffer; if
        // the script's output exceeds that and nobody reads, the
        // script's write() blocks → process never exits →
        // terminationHandler never fires → UI sticks on "loading".
        let stdoutLock = NSLock()
        var stdoutBuffer = Data()
        outPipe.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            guard !chunk.isEmpty else { return }
            stdoutLock.lock()
            stdoutBuffer.append(chunk)
            stdoutLock.unlock()
        }

        process.terminationHandler = { [weak self] proc in
            guard let self else { return }

            self.lock.lock()
            let isLatest = (mySeq == self.requestSeq)
            if isLatest { self.inflight = nil }
            self.lock.unlock()

            if let cleanup = plan.cleanupURL {
                try? FileManager.default.removeItem(at: cleanup)
            }

            errPipe.fileHandleForReading.readabilityHandler = nil
            let trailingErr = errPipe.fileHandleForReading.availableData
            stderrLock.lock()
            if !trailingErr.isEmpty { stderrBuffer.append(trailingErr) }
            let errString = String(data: stderrBuffer, encoding: .utf8) ?? ""
            stderrLock.unlock()

            outPipe.fileHandleForReading.readabilityHandler = nil
            let trailingOut = outPipe.fileHandleForReading.availableData
            stdoutLock.lock()
            if !trailingOut.isEmpty { stdoutBuffer.append(trailingOut) }
            let outData = stdoutBuffer
            stdoutLock.unlock()

            guard isLatest else {
                DispatchQueue.main.async { completion(.failure(.cancelled)) }
                return
            }

            if proc.terminationStatus != 0 {
                DispatchQueue.main.async {
                    completion(.failure(.nonZeroExit(code: proc.terminationStatus, stderr: errString)))
                }
                return
            }

            do {
                let parsed = try JSONDecoder().decode(AlfredScriptFilterOutput.self, from: outData)
                DispatchQueue.main.async { completion(.success(parsed.items)) }
            } catch {
                let raw = String(data: outData, encoding: .utf8) ?? ""
                DispatchQueue.main.async {
                    completion(.failure(.decodeFailed(error, raw: raw)))
                }
            }
        }

        do {
            try process.run()
        } catch {
            lock.lock()
            if inflight === process { inflight = nil }
            lock.unlock()
            if let cleanup = plan.cleanupURL {
                try? FileManager.default.removeItem(at: cleanup)
            }
            DispatchQueue.main.async { completion(.failure(.launchFailed(error))) }
        }
    }

    func cancel() {
        lock.lock()
        requestSeq += 1
        inflight?.terminate()
        inflight = nil
        lock.unlock()
    }
}
