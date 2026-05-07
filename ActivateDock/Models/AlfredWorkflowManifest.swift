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
    let runningsubtext: String?
    // Alfred's "script language" picker — bash / zsh / php / ruby /
    // python / osascript(AS) / osascript(JS) / etc. The integer is
    // the index into Alfred's dropdown. Inline scripts with a #!
    // shebang override this. ScriptInvocation maps it to a concrete
    // interpreter command line.
    let type: Int?
}

extension WorkflowObject {
    static let scriptFilterType = "alfred.workflow.input.scriptfilter"
    var isScriptFilter: Bool { type == Self.scriptFilterType }
}
