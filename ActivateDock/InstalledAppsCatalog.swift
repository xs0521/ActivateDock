//
//  InstalledAppsCatalog.swift
//  ActivateDock
//

import Cocoa

struct InstalledApp {
    let url: URL
    let displayName: String
    let lowercaseName: String
    let icon: NSImage
}

enum InstalledAppsCatalog {
    static func loadAll() -> [InstalledApp] {
        let paths = [
            "/Applications",
            "/System/Applications",
            (NSString(string: "~/Applications").expandingTildeInPath)
        ]
        var seen = Set<String>()
        var result: [InstalledApp] = []
        for p in paths {
            for app in scan(path: p, depth: 0, maxDepth: 2) {
                if seen.insert(app.url.path).inserted {
                    result.append(app)
                }
            }
        }
        return result.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    private static func scan(path: String, depth: Int, maxDepth: Int) -> [InstalledApp] {
        guard depth <= maxDepth else { return [] }
        let url = URL(fileURLWithPath: path)
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var apps: [InstalledApp] = []
        for entry in entries {
            if entry.pathExtension == "app" {
                let icon = NSWorkspace.shared.icon(forFile: entry.path)
                icon.size = NSSize(width: 32, height: 32)
                let name = displayName(for: entry)
                apps.append(InstalledApp(
                    url: entry,
                    displayName: name,
                    lowercaseName: name.lowercased(),
                    icon: icon
                ))
            } else if let isDir = (try? entry.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory, isDir {
                apps.append(contentsOf: scan(path: entry.path, depth: depth + 1, maxDepth: maxDepth))
            }
        }
        return apps
    }

    private static func displayName(for url: URL) -> String {
        if let bundle = Bundle(url: url) {
            if let n = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String, !n.isEmpty { return n }
            if let n = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String, !n.isEmpty { return n }
        }
        return url.deletingPathExtension().lastPathComponent
    }

    static func search(_ query: String, in apps: [InstalledApp], limit: Int = 30) -> [InstalledApp] {
        let q = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return [] }
        var prefix: [InstalledApp] = []
        var contains: [InstalledApp] = []
        for app in apps {
            let n = app.lowercaseName
            if n.hasPrefix(q) { prefix.append(app) }
            else if n.contains(q) { contains.append(app) }
        }
        return Array((prefix + contains).prefix(limit))
    }
}
