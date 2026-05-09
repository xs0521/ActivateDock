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
    let description: String?
    let variables: [String: String]?
    // ActivateDock-specific extension — Alfred's schema has no native
    // "this variable holds a credential" marker. Plugin authors can
    // list variable names here to force secure storage + masked UI,
    // overriding the name-based heuristic in PluginVariableSensitivity.
    let secretvariables: [String]?
    // Alfred's "Workflow Configuration" schema — describes the
    // user-editable variables (textfields, sliders, popups, etc.)
    // and their defaults. Keyword fields can reference these via
    // `{var:NAME}`, which the loader resolves against the merged
    // userconfig defaults + top-level variables.
    let userconfigurationconfig: [UserConfigEntry]?
    let objects: [WorkflowObject]?
    // Directed edges between objects: sourceUID → [connection]
    let connections: [String: [ManifestConnection]]?
}

// One directed edge in the plist connection graph.
struct ManifestConnection: Decodable {
    let destinationuid: String?
    // Alfred bitmask: 0=default 1=cmd 2=alt 4=ctrl 8=shift 16=fn (combinable)
    let modifiers: Int?
}

struct UserConfigEntry: Decodable {
    let variable: String?
    let type: String?
    let label: String?
    let description: String?
    let config: UserConfigEntryConfig?
}

struct UserConfigEntryConfig: Decodable {
    // textfield / popupbutton / etc. defaults live in `default`
    // (string). slider stores its starting value under `defaultvalue`
    // as a number. Other fields (placeholder, required, …) exist but
    // aren't needed for keyword expansion.
    let `default`: String?
    let defaultvalue: Double?
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
    let subtext: String?
    let runningsubtext: String?
    // Alfred's "script language" picker — bash / zsh / php / ruby /
    // python / osascript(AS) / osascript(JS) / etc. The integer is
    // the index into Alfred's dropdown. Inline scripts with a #!
    // shebang override this. ScriptInvocation maps it to a concrete
    // interpreter command line.
    let type: Int?
    // action.openurl
    let url: String?
    // action.copytoclipboard
    let text: String?
    // utility.argument
    let argument: String?
    let passthroughargument: Bool?
    // input.listfilter: Alfred stores items as a JSON-encoded string, not a
    // native plist array. Expand {var:NAME} in this string, then JSON-decode.
    let items: String?
}

// One static item decoded from the JSON string in an input.listfilter config.
struct WorkflowListFilterItem: Decodable {
    let uid: String?
    let title: String?
    let subtitle: String?
    let arg: String?
    let icon: AlfredIcon?
}

extension WorkflowObject {
    static let scriptFilterType    = "alfred.workflow.input.scriptfilter"
    static let keywordInputType    = "alfred.workflow.input.keyword"
    static let listFilterInputType = "alfred.workflow.input.listfilter"
    static let actionScriptType    = "alfred.workflow.action.script"
    static let actionOpenURLType   = "alfred.workflow.action.openurl"
    static let actionCopyType      = "alfred.workflow.action.copytoclipboard"
    static let utilityArgumentType = "alfred.workflow.utility.argument"
    static let utilityJunctionType = "alfred.workflow.utility.junction"
    var isScriptFilter:    Bool { type == Self.scriptFilterType }
    var isKeywordInput:    Bool { type == Self.keywordInputType }
    var isListFilterInput: Bool { type == Self.listFilterInputType }
}
