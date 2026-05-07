//
//  AlfredWorkflowLoader.swift
//  ActivateDock
//
//  Walks the plugin install root, parses each subdirectory's info.plist,
//  and yields a flat list of Workflow values. One Alfred plugin can
//  contribute multiple Script Filters; each becomes its own Workflow.
//
//  Bad plugins are logged and skipped — never throw out of loadAll().
//

import Foundation

enum AlfredWorkflowLoader {

    static func loadAll(at root: URL) -> [Workflow] {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var result: [Workflow] = []
        for dir in entries {
            let isDir = (try? dir.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            guard isDir else { continue }
            result.append(contentsOf: loadOne(at: dir))
        }
        return result
    }

    private static func loadOne(at directory: URL) -> [Workflow] {
        let plistURL = directory.appendingPathComponent("info.plist")
        guard let data = try? Data(contentsOf: plistURL) else {
            NSLog("[AlfredWorkflowLoader] no info.plist in \(directory.path), skipping")
            return []
        }

        let manifest: AlfredWorkflowManifest
        do {
            manifest = try PropertyListDecoder().decode(AlfredWorkflowManifest.self, from: data)
        } catch {
            NSLog("[AlfredWorkflowLoader] decode failed for \(directory.path): \(error)")
            return []
        }

        guard let objects = manifest.objects else { return [] }
        let bundleId = manifest.bundleid ?? directory.lastPathComponent
        let displayName = manifest.name ?? directory.lastPathComponent
        let variables = manifest.variables ?? [:]

        var workflows: [Workflow] = []
        for obj in objects where obj.isScriptFilter {
            guard let cfg = obj.config,
                  let keyword = cfg.keyword?.trimmingCharacters(in: .whitespaces),
                  !keyword.isEmpty,
                  let script = cfg.script?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !script.isEmpty
            else {
                NSLog("[AlfredWorkflowLoader] scriptfilter in \(directory.lastPathComponent) missing keyword or script, skipping")
                continue
            }
            workflows.append(Workflow(
                bundleId: bundleId,
                name: displayName,
                directory: directory,
                keyword: keyword,
                scriptCommand: script,
                variables: variables
            ))
        }
        return workflows
    }
}
