//
//  AlfredWorkflowLoader+NodeBuilding.swift
//  ActivateDock
//
//  Static helpers that translate raw WorkflowObject / connection entries
//  from info.plist into typed WorkflowNode values and WorkflowGraph.Edge
//  dictionaries. Split from AlfredWorkflowLoader.swift to stay under the
//  200-line limit.
//

import AppKit

extension AlfredWorkflowLoader {

    // Returns nil for unknown or structurally incomplete objects.
    // Callers skip nil entries; scriptfilter callers additionally record failures.
    static func buildNode(from obj: WorkflowObject,
                          bundleId: String,
                          name: String,
                          effectiveVars: [String: String]) -> (any WorkflowNode)? {
        let uid = obj.uid ?? UUID().uuidString
        switch obj.type {
        case WorkflowObject.scriptFilterType:
            guard let raw = obj.config?.script?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !raw.isEmpty else { return nil }
            return ScriptFilterNode(uid: uid, bundleId: bundleId, name: name,
                                     scriptCommand: expand(raw, with: effectiveVars),
                                     scriptLanguageType: obj.config?.type)
        case WorkflowObject.actionScriptType:
            guard let raw = obj.config?.script?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !raw.isEmpty else { return nil }
            return ActionScriptNode(uid: uid, bundleId: bundleId,
                                     scriptCommand: expand(raw, with: effectiveVars),
                                     scriptLanguageType: obj.config?.type)
        case WorkflowObject.actionOpenURLType:
            return ActionOpenURLNode(uid: uid, urlTemplate: obj.config?.url ?? "")
        case WorkflowObject.actionCopyType:
            return ActionCopyToClipboardNode(uid: uid, textTemplate: obj.config?.text ?? "")
        case WorkflowObject.keywordInputType:
            let title = obj.config?.title?.trimmingCharacters(in: .whitespacesAndNewlines)
            return KeywordInputNode(uid: uid,
                                    title: (title?.isEmpty ?? true) ? name : title!,
                                    subtitle: obj.config?.runningsubtext)
        case WorkflowObject.listFilterInputType:
            // Dynamic mode: has a script → behave exactly like scriptfilter
            if let raw = obj.config?.script?.trimmingCharacters(in: .whitespacesAndNewlines),
               !raw.isEmpty {
                return ScriptFilterNode(uid: uid, bundleId: bundleId, name: name,
                                         scriptCommand: expand(raw, with: effectiveVars),
                                         scriptLanguageType: obj.config?.type)
            }
            // Static mode: decode plist items, expand {var:NAME}, pre-build AlfredItems
            let alfredItems = (obj.config?.items ?? []).compactMap { item -> AlfredItem? in
                guard let raw = item.title, !raw.isEmpty else { return nil }
                return AlfredItem(title: expand(raw, with: effectiveVars),
                                  subtitle: item.subtitle.map { expand($0, with: effectiveVars) },
                                  arg: item.arg.map { expand($0, with: effectiveVars) },
                                  icon: item.icon, mods: nil, variables: nil, valid: nil)
            }
            return ListFilterInputNode(uid: uid, rawItems: alfredItems)
        case WorkflowObject.utilityJunctionType:
            return UtilityJunctionNode(uid: uid)
        default:
            return nil
        }
    }

    // Translate the plist connections dict into typed WorkflowGraph.Edge arrays.
    static func buildEdges(from manifest: AlfredWorkflowManifest) -> [String: [WorkflowGraph.Edge]] {
        var result: [String: [WorkflowGraph.Edge]] = [:]
        for (srcUID, connections) in manifest.connections ?? [:] {
            let edges = connections.compactMap { conn -> WorkflowGraph.Edge? in
                guard let dst = conn.destinationuid else { return nil }
                let mods = NSEvent.ModifierFlags.fromAlfredEdgeMask(conn.modifiers ?? 0)
                return WorkflowGraph.Edge(destination: dst, modifiers: mods)
            }
            if !edges.isEmpty { result[srcUID] = edges }
        }
        return result
    }
}
