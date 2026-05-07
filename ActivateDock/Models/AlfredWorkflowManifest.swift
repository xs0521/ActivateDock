//
//  AlfredWorkflowManifest.swift
//  ActivateDock
//
//  Codable subset of Alfred's `info.plist`. Only the fields we need to
//  surface a Script Filter are decoded; everything else (connections,
//  UI metadata, non-scriptfilter object types) is ignored.
//

import Foundation

struct AlfredWorkflowManifest: Decodable {
    let bundleid: String?
    let name: String?
    let variables: [String: String]?
    let objects: [WorkflowObject]?
}

struct WorkflowObject: Decodable {
    let type: String
    let uid: String?
    let config: WorkflowObjectConfig?
}

struct WorkflowObjectConfig: Decodable {
    let keyword: String?
    let script: String?
    let scriptargtype: Int?
    let title: String?
    let runningsubtext: String?
}

extension WorkflowObject {
    static let scriptFilterType = "alfred.workflow.input.scriptfilter"
    var isScriptFilter: Bool { type == Self.scriptFilterType }
}
