//
//  Workflow.swift
//  ActivateDock
//
//  Runtime representation of a single Script Filter loaded from a plugin
//  on disk. Built by AlfredWorkflowLoader.
//

import Foundation

struct Workflow {
    let bundleId: String
    let name: String
    let description: String?
    let directory: URL
    let keyword: String
    let scriptCommand: String
    let variables: [String: String]

    func substitutedCommand(query: String) -> String {
        let quoted = Self.shellQuote(query)
        return scriptCommand.replacingOccurrences(of: "{query}", with: quoted)
    }

    private static func shellQuote(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    func resolvingIconPaths(in items: [AlfredItem]) -> [AlfredItem] {
        items.map { item in
            guard let path = item.icon?.path, !path.isEmpty, !path.hasPrefix("/") else {
                return item
            }
            let abs = directory.appendingPathComponent(path).path
            return AlfredItem(
                title: item.title,
                subtitle: item.subtitle,
                arg: item.arg,
                icon: AlfredIcon(path: abs)
            )
        }
    }
}
