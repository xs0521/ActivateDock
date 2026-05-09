//
//  AlfredWorkflowLoader.swift
//  ActivateDock
//
//  Walks the plugin install root, parses each subdirectory's info.plist,
//  and yields a list of WorkflowGraph values. One Alfred plugin becomes
//  one graph; each scriptfilter object inside it becomes a ScriptFilterNode
//  with its own entry in the graph's nodes dict and entrypoints list.
//
//  Bad plugins are recorded as PluginLoadFailure entries on the returned
//  LoadResult so WorkflowRegistry can surface them in the Settings UI —
//  never thrown out of loadAll().
//

import Foundation

enum AlfredWorkflowLoader {

    struct LoadResult {
        var graphs: [WorkflowGraph] = []
        var failures: [PluginLoadFailure] = []

        mutating func merge(_ other: LoadResult) {
            graphs.append(contentsOf: other.graphs)
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
        var result = LoadResult()
        let plistURL = directory.appendingPathComponent("info.plist")
        guard let data = try? Data(contentsOf: plistURL) else {
            NSLog("[AlfredWorkflowLoader] no info.plist in \(directory.path), skipping")
            result.failures.append(PluginLoadFailure(directory: directory, reason: .missingInfoPlist))
            return result
        }

        let manifest: AlfredWorkflowManifest
        do {
            manifest = try PropertyListDecoder().decode(AlfredWorkflowManifest.self, from: data)
        } catch {
            let detail = (error as NSError).localizedDescription
            NSLog("[AlfredWorkflowLoader] decode failed for \(directory.path): \(error)")
            result.failures.append(PluginLoadFailure(directory: directory,
                                                      reason: .decodeFailed(detail: detail)))
            return result
        }

        guard let objects = manifest.objects else { return result }
        let bundleId      = manifest.bundleid ?? directory.lastPathComponent
        let displayName   = manifest.name ?? directory.lastPathComponent
        let description   = manifest.description?.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveVars = mergedVariables(userConfig: manifest.userconfigurationconfig,
                                            topLevel: manifest.variables)
        let declaredSecrets = Set(manifest.secretvariables ?? [])

        var nodes: [String: any WorkflowNode] = [:]
        var entrypoints: [WorkflowGraph.Entrypoint] = []

        for obj in objects {
            guard let node = buildNode(from: obj, bundleId: bundleId, name: displayName,
                                        effectiveVars: effectiveVars) else {
                if obj.isScriptFilter {
                    NSLog("[AlfredWorkflowLoader] scriptfilter in \(directory.lastPathComponent) missing script, skipping")
                    result.failures.append(PluginLoadFailure(directory: directory,
                                                              reason: .missingScriptFilterFields(objectUid: obj.uid)))
                }
                continue
            }
            nodes[node.uid] = node

            guard (obj.isScriptFilter || obj.isKeywordInput || obj.isListFilterInput),
                  let rawKeyword = obj.config?.keyword?.trimmingCharacters(in: .whitespaces),
                  !rawKeyword.isEmpty else {
                if obj.isScriptFilter {
                    NSLog("[AlfredWorkflowLoader] scriptfilter in \(directory.lastPathComponent) missing keyword, skipping entrypoint")
                    result.failures.append(PluginLoadFailure(directory: directory,
                                                              reason: .missingScriptFilterFields(objectUid: obj.uid)))
                }
                continue
            }
            let expanded = expand(rawKeyword, with: effectiveVars)
            let keywords = expanded.split(separator: "||").map {
                String($0).trimmingCharacters(in: .whitespaces)
            }.filter { !$0.isEmpty }
            for keyword in keywords {
                entrypoints.append(WorkflowGraph.Entrypoint(keyword: keyword, nodeUID: node.uid))
            }
        }

        guard !entrypoints.isEmpty else { return result }
        result.graphs.append(WorkflowGraph(
            bundleId: bundleId, name: displayName,
            description: (description?.isEmpty ?? true) ? nil : description,
            pluginDirectory: directory, nodes: nodes,
            edges: buildEdges(from: manifest),
            entrypoints: entrypoints, variables: effectiveVars,
            declaredSecretVariables: declaredSecrets
        ))
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
        for (k, v) in topLevel ?? [:] { result[k] = v }
        return result
    }

    static func expand(_ template: String, with vars: [String: String]) -> String {
        guard template.contains("{var:") else { return template }
        let pattern = #"\{var:([A-Za-z_][A-Za-z0-9_]*)\}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return template }
        let ns = template as NSString
        let matches = regex.matches(in: template, range: NSRange(location: 0, length: ns.length))
        var result = template
        for match in matches.reversed() {
            let name = ns.substring(with: match.range(at: 1))
            result = (result as NSString).replacingCharacters(in: match.range, with: vars[name] ?? "")
        }
        return result
    }
}
