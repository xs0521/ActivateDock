//
//  PluginPaths.swift
//  ActivateDock
//

import Foundation

enum PluginPaths {
    static var root: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory,
                                                  in: .userDomainMask)[0]
        return appSupport
            .appendingPathComponent("ActivateDock", isDirectory: true)
            .appendingPathComponent("Plugins", isDirectory: true)
    }

    static func ensureExists() {
        try? FileManager.default.createDirectory(at: root,
                                                 withIntermediateDirectories: true)
    }
}
