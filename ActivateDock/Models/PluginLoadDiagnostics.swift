//
//  PluginLoadDiagnostics.swift
//  ActivateDock
//
//  Value types describing things that went wrong while WorkflowRegistry
//  was building its keyword index — used by the Settings UI so users
//  can see which plugins didn't load and which keywords collided,
//  instead of having to read NSLog output.
//

import Foundation

struct PluginLoadFailure {
    enum Reason {
        case missingInfoPlist
        case decodeFailed(detail: String)
        case missingScriptFilterFields(objectUid: String?)
    }
    let directory: URL
    let reason: Reason

    var directoryName: String { directory.lastPathComponent }
}

extension PluginLoadFailure.Reason {
    var displayMessage: String {
        switch self {
        case .missingInfoPlist:
            return "info.plist not found"
        case .decodeFailed(let detail):
            return "failed to parse info.plist: \(detail)"
        case .missingScriptFilterFields(let uid):
            let suffix = uid.map { " (object \($0))" } ?? ""
            return "script filter missing keyword or script\(suffix)"
        }
    }
}

struct PluginKeywordConflict {
    let keyword: String
    let keptBundleId: String
    let droppedBundleIds: [String]
}
