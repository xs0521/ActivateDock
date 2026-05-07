//
//  ScriptInvocation.swift
//  ActivateDock
//
//  Builds a Process invocation plan for an Alfred Script Filter.
//  Alfred plugins can ship script bodies in many languages — bash,
//  zsh, ruby, python, AppleScript, JXA — and pick the runtime via
//  the `type` field on the script-filter config (or via a #! shebang
//  embedded in the script body itself).
//
//  Strategy:
//    1. Substitute `{query}` (shell-quoted) into the script body.
//    2. Write the resulting body to a temp file.
//    3. If the body has a shebang → chmod +x and run it directly.
//       Otherwise look up the `type` integer to pick an interpreter,
//       falling back to /bin/sh when unknown.
//
//  The runner cleans up the temp file in its terminationHandler.
//

import Foundation

enum ScriptInvocation {

    struct Plan {
        let executable: URL
        let arguments: [String]
        /// Temp script path the caller should remove after the
        /// process exits.
        let cleanupURL: URL?
    }

    enum PlanError: Error, LocalizedError {
        case writeFailed(Error)
        case chmodFailed(Error)

        var errorDescription: String? {
            switch self {
            case .writeFailed(let e): return "Could not write script: \(e.localizedDescription)"
            case .chmodFailed(let e): return "Could not chmod script: \(e.localizedDescription)"
            }
        }
    }

    static func plan(body: String, scriptLanguageType: Int?, bundleId: String) throws -> Plan {
        let scriptURL = try writeTempScript(body: body, hint: bundleId)

        if body.hasPrefix("#!") {
            do {
                try FileManager.default.setAttributes(
                    [.posixPermissions: 0o755],
                    ofItemAtPath: scriptURL.path
                )
            } catch {
                try? FileManager.default.removeItem(at: scriptURL)
                throw PlanError.chmodFailed(error)
            }
            return Plan(executable: scriptURL, arguments: [], cleanupURL: scriptURL)
        }

        let interpreter = interpretersByType[scriptLanguageType ?? -1] ?? defaultInterpreter
        let exec = URL(fileURLWithPath: interpreter[0])
        let args = Array(interpreter.dropFirst()) + [scriptURL.path]
        return Plan(executable: exec, arguments: args, cleanupURL: scriptURL)
    }

    private static func writeTempScript(body: String, hint: String) throws -> URL {
        let safeHint = hint
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ActivateDock-\(safeHint)-\(UUID().uuidString).script")
        do {
            try Data(body.utf8).write(to: url, options: .atomic)
        } catch {
            throw PlanError.writeFailed(error)
        }
        return url
    }

    // Best-guess Alfred script-type → interpreter table. Each entry's
    // first element is the executable; remaining elements are option
    // flags that precede the script path. Values not in this table
    // fall back to /bin/sh, which handles bash-compatible scripts.
    private static let interpretersByType: [Int: [String]] = [
        0: ["/bin/bash"],
        1: ["/usr/bin/php"],
        2: ["/usr/bin/ruby"],
        3: ["/usr/bin/perl"],
        4: ["/bin/zsh"],
        5: ["/usr/bin/python3"],
        6: ["/usr/bin/osascript"],
        7: ["/usr/bin/osascript", "-l", "JavaScript"]
    ]

    private static let defaultInterpreter: [String] = ["/bin/sh"]
}
