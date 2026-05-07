//
//  ActionCopyToClipboardNode.swift
//  ActivateDock
//
//  Writes resolved text to the system clipboard, then returns .terminal.
//  Must run on the main thread (NSPasteboard requirement).
//

import AppKit

final class ActionCopyToClipboardNode: WorkflowNode {
    let uid: String
    let nodeType = "action.copytoclipboard"
    private let textTemplate: String

    init(uid: String, textTemplate: String) {
        self.uid = uid
        self.textTemplate = textTemplate
    }

    func execute(input: NodeInput, context: WorkflowContext,
                 completion: @escaping (Result<NodeOutput, WorkflowError>) -> Void) {
        let resolved = textTemplate.replacingOccurrences(of: "{query}", with: input.arg ?? "")
        DispatchQueue.main.async {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(resolved, forType: .string)
            completion(.success(.terminal))
        }
    }
}
