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
        let variables = manifest.variables ?? [:]
        let declaredSecrets = Set(manifest.secretvariables ?? [])

        var result = LoadResult()
        for obj in objects where obj.isScriptFilter {
            guard let cfg = obj.config,
                  let keyword = cfg.keyword?.trimmingCharacters(in: .whitespaces),
                  !keyword.isEmpty,
                  let script = cfg.script?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !script.isEmpty
            else {
                NSLog("[AlfredWorkflowLoader] scriptfilter in \(directory.lastPathComponent) missing keyword or script, skipping")
                result.failures.append(PluginLoadFailure(
                    directory: directory,
                    reason: .missingScriptFilterFields(objectUid: obj.uid)
                ))
                continue
            }
            result.workflows.append(Workflow(
                bundleId: bundleId,
                name: displayName,
                description: (description?.isEmpty ?? true) ? nil : description,
                directory: directory,
                keyword: keyword,
                scriptCommand: script,
                variables: variables,
                declaredSecretVariables: declaredSecrets
            ))
        }
        return result
    }
}
