//
//  AlfredScriptFilterRunner.swift
//  ActivateDock
//
//  Spawns an Alfred-compatible Script Filter (any binary that prints
//  `{ "items": [...] }` to stdout) and decodes the result. Cancels any
//  prior in-flight invocation when a new one arrives.
//

import Foundation

enum AlfredRunnerError: Error {
    case launchFailed(Error)
    case nonZeroExit(code: Int32, stderr: String)
    case decodeFailed(Error, raw: String)
    case cancelled
}

final class AlfredScriptFilterRunner {
    let runtimePath: String
    let scriptPath: String
    let workingDirectory: String?

    private let lock = NSLock()
    private var inflight: Process?
    private var requestSeq: Int = 0

    init(runtimePath: String, scriptPath: String, workingDirectory: String? = nil) {
        self.runtimePath = runtimePath
        self.scriptPath = scriptPath
        self.workingDirectory = workingDirectory
    }

    func run(query: String,
             env: [String: String] = [:],
             completion: @escaping (Result<[AlfredItem], AlfredRunnerError>) -> Void) {

        lock.lock()
        requestSeq += 1
        let mySeq = requestSeq
        inflight?.terminate()
        let process = Process()
        inflight = process
        lock.unlock()

        process.executableURL = URL(fileURLWithPath: runtimePath)
        process.arguments = ["run", scriptPath, query]
        if let cwd = workingDirectory {
            process.currentDirectoryURL = URL(fileURLWithPath: cwd)
        }

        var mergedEnv = ProcessInfo.processInfo.environment
        for (k, v) in env { mergedEnv[k] = v }
        process.environment = mergedEnv

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        process.terminationHandler = { [weak self] proc in
            guard let self else { return }

            self.lock.lock()
            let isLatest = (mySeq == self.requestSeq)
            if isLatest { self.inflight = nil }
            self.lock.unlock()

            let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
            let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            let errString = String(data: errData, encoding: .utf8) ?? ""

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
