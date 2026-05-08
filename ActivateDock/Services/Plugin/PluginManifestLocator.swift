//
//  PluginManifestLocator.swift
//  ActivateDock
//

import Foundation

enum PluginManifestLocator {

    static func locateRoot(in dir: URL) throws -> URL {
        let fm = FileManager.default
        if fm.fileExists(atPath: dir.appendingPathComponent("info.plist").path) {
            return dir
        }

        let entries = (try? fm.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        for entry in entries {
            let values = try? entry.resourceValues(forKeys: [.isDirectoryKey])
            guard values?.isDirectory == true else { continue }
            if fm.fileExists(atPath: entry.appendingPathComponent("info.plist").path) {
                return entry
            }
        }
        throw PluginImporter.ImportError.missingManifest
    }

    static func parseManifest(at dir: URL) throws -> AlfredWorkflowManifest {
        let plistURL = dir.appendingPathComponent("info.plist")
        do {
            let data = try Data(contentsOf: plistURL)
            return try PropertyListDecoder().decode(AlfredWorkflowManifest.self, from: data)
        } catch {
            throw PluginImporter.ImportError.manifestDecodeFailed(
                detail: (error as NSError).localizedDescription
            )
        }
    }

    static func findExistingInstall(bundleId: String) -> URL? {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(
            at: PluginPaths.root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }

        for entry in entries {
            let plistURL = entry.appendingPathComponent("info.plist")
            guard let data = try? Data(contentsOf: plistURL),
                  let manifest = try? PropertyListDecoder().decode(
                    AlfredWorkflowManifest.self,
                    from: data
                  ),
                  manifest.bundleid == bundleId
            else { continue }
            return entry
        }
        return nil
    }
}
