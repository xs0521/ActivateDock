//
//  ListFilterInputNode.swift
//  ActivateDock
//
//  Alfred `input.listfilter` node (static-items mode).
//  Items are pre-built from the plist at load time; at execute time they are
//  filtered by the user's query (case-insensitive contains on title/subtitle)
//  and any relative icon paths are resolved against the plugin directory.
//
//  Dynamic mode (config.script is present) is handled by ScriptFilterNode —
//  the loader builds a ScriptFilterNode instead of this type in that case.
//

import Foundation

struct ListFilterInputNode: WorkflowNode {
    let uid: String
    let nodeType = "input.listfilter"
    /// Pre-built items; icon paths may still be relative at this point.
    let rawItems: [AlfredItem]

    func execute(input: NodeInput,
                 context: WorkflowContext,
                 completion: @escaping (Result<NodeOutput, WorkflowError>) -> Void) {
        let pluginDir = context.graph.pluginDirectory
        let resolved = rawItems.map { item -> AlfredItem in
            guard let path = item.icon?.path, !path.isEmpty, !path.hasPrefix("/") else { return item }
            let abs = pluginDir.appendingPathComponent(path).path
            return AlfredItem(title: item.title, subtitle: item.subtitle,
                              arg: item.arg, icon: AlfredIcon(path: abs),
                              mods: item.mods, variables: item.variables, valid: item.valid)
        }
        let query = (input.arg ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let filtered = query.isEmpty ? resolved : resolved.filter {
            $0.title.lowercased().contains(query) ||
            ($0.subtitle?.lowercased().contains(query) ?? false)
        }
        completion(.success(.items(filtered)))
    }
}
