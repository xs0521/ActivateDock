//
//  AlfredWorkflowLoader.swift
//  ActivateDock
//
//  Walks the plugin install root, parses each subdirectory's info.plist,
//  and yields a flat list of Workflow values. One Alfred plugin can
//  contribute multiple Script Filters; each becomes its own Workflow.
//
//  Bad plugins are recorded as PluginLoadFailure entries on the
//  returned LoadResult so WorkflowRegistry can surface them in the
//  Settings UI — never thrown out of loadAll().
//

import Foundation

enum AlfredWorkflowLoader {

    struct LoadResult {
        var workflows: [Workflow] = []
        var failures: [PluginLoadFailure] = []

        mutating func merge(_ other: LoadResult) {
            workflows.append(contentsOf: other.workflows)
            failures.append(contentsOf: other.failures)
        }
    }

    static func loadAll(at root: URL) -> LoadResult {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return LoadResult() }

        var result = LoadResult()
        for dir in entries {
            let isDir = (try? dir.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            guard isDir else { continue }
            result.merge(loadOne(at: dir))
        }
        return result
    }

    private static func loadOne(at directory: URL) -> LoadResult {
        let plistURL = directory.appendingPathComponent("info.plist")
        guard let data = try? Data(contentsOf: plistURL) else {
            NSLog("[AlfredWorkflowLoader] no info.plist in \(directory.path), skipping")
            return LoadResult(workflows: [], failures: [
                PluginLoadFailure(directory: directory, reason: .missingInfoPlist)
            ])
        }

        let manifest: AlfredWorkflowManifest
        do {
            manifest = try PropertyListDecoder().decode(AlfredWorkflowManifest.self, from: data)
        } catch {
            let detail = (error as NSError).localizedDescription
            NSLog("[AlfredWorkflowLoader] decode failed for \(directory.path): \(error)")
            return LoadResult(workflows: [], failures: [
                PluginLoadFailure(directory: directory, reason: .decodeFailed(detail: detail))
            ])
        }

        guard let objects = manifest.objects else { return LoadResult() }
        let bundleId = manifest.bundleid ?? directory.lastPathComponent
        let displayName = manifest.name ?? directory.lastPathComponent
        let description = manifest.description?.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveVariables = mergedVariables(
            userConfig: manifest.userconfigurationconfig,
            topLevel: manifest.variables
        )
        let declaredSecrets = Set(manifest.secretvariables ?? [])

        var result = LoadResult()
        for obj in objects where obj.isScriptFilter {
            guard let cfg = obj.config,
                  let rawKeyword = cfg.keyword?.trimmingCharacters(in: .whitespaces),
                  !rawKeyword.isEmpty,
                  let rawScript = cfg.script?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !rawScript.isEmpty
            else {
                NSLog("[AlfredWorkflowLoader] scriptfilter in \(directory.lastPathComponent) missing keyword or script, skipping")
                result.failures.append(PluginLoadFailure(
                    directory: directory,
                    reason: .missingScriptFilterFields(objectUid: obj.uid)
                ))
                continue
            }
            let keyword = expand(rawKeyword, with: effectiveVariables)
                .trimmingCharacters(in: .whitespaces)
            guard !keyword.isEmpty else {
                NSLog("[AlfredWorkflowLoader] scriptfilter in \(directory.lastPathComponent) keyword '\(rawKeyword)' resolved to empty, skipping")
                result.failures.append(PluginLoadFailure(
                    directory: directory,
                    reason: .missingScriptFilterFields(objectUid: obj.uid)
                ))
                continue
            }
            let script = expand(rawScript, with: effectiveVariables)
            result.workflows.append(Workflow(
                bundleId: bundleId,
                name: displayName,
                description: (description?.isEmpty ?? true) ? nil : description,
                directory: directory,
                keyword: keyword,
                scriptCommand: script,
                scriptLanguageType: cfg.type,
                variables: effectiveVariables,
                declaredSecretVariables: declaredSecrets
            ))
        }
        return result
    }

    private static func mergedVariables(
        userConfig: [UserConfigEntry]?,
        topLevel: [String: String]?
    ) -> [String: String] {
        var result: [String: String] = [:]
        for entry in userConfig ?? [] {
            guard let key = entry.variable, !key.isEmpty else { continue }
            if let str = entry.config?.default {
                result[key] = str
            } else if let num = entry.config?.defaultvalue {
                let isWhole = num.truncatingRemainder(dividingBy: 1) == 0
                result[key] = isWhole ? String(Int(num)) : String(num)
            }
        }
        // top-level `variables` is the user/installer's last word and
        // overrides userconfig defaults when both define the same key.
        for (k, v) in topLevel ?? [:] { result[k] = v }
        return result
    }

    private static func expand(_ template: String, with vars: [String: String]) -> String {
        guard template.contains("{var:") else { return template }
        let pattern = #"\{var:([A-Za-z_][A-Za-z0-9_]*)\}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return template }
        let ns = template as NSString
        let matches = regex.matches(in: template, range: NSRange(location: 0, length: ns.length))
        var result = template
        for match in matches.reversed() {
            let name = ns.substring(with: match.range(at: 1))
            let replacement = vars[name] ?? ""
            result = (result as NSString).replacingCharacters(in: match.range, with: replacement)
        }
        return result
    }
}
