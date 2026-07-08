//
//  PluginImporter.swift
//  ActivateDock
//
//  Imports an Alfred-style plugin from a .alfredworkflow / .zip file
//  or a directory into the user's Plugins root. Validates the manifest
//  before installing and detects existing installs by bundleid (not
//  just folder name) so re-importing replaces the right plugin.
//
//  PluginWatcher picks up the resulting filesystem change and triggers
//  WorkflowRegistry.reload(); this importer never touches the registry
//  itself — it just lays files down on disk.
//

import Foundation

enum PluginImporter {

    struct ImportResult {
        let installedAt: URL
        let bundleId: String
        let displayName: String
    }

    enum ImportError: Error, LocalizedError {
        case unsupportedFile
        case unzipFailed(detail: String)
        case missingManifest
        case manifestDecodeFailed(detail: String)
        case alreadyExists(bundleId: String, folderName: String)
        case copyFailed(detail: String)

        var errorDescription: String? {
            switch self {
            case .unsupportedFile:
                return L("plugins.error.unsupported_file")
            case .unzipFailed(let detail):
                return L("plugins.error.unzip_failed", detail)
            case .missingManifest:
                return L("plugins.error.missing_manifest")
            case .manifestDecodeFailed(let detail):
                return L("plugins.error.manifest_decode_failed", detail)
            case .alreadyExists(let bundleId, _):
                return L("plugins.error.already_exists", bundleId)
            case .copyFailed(let detail):
                return L("plugins.error.copy_failed", detail)
            }
        }
    }

    static func install(from source: URL, replaceExisting: Bool) throws -> ImportResult {
        let staged = try PluginImportStager.stage(source)
        defer { try? FileManager.default.removeItem(at: staged.tempRoot) }

        let pluginRoot = try PluginManifestLocator.locateRoot(in: staged.contentRoot)
        let manifest = try PluginManifestLocator.parseManifest(at: pluginRoot)

        let bundleId = manifest.bundleid?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nonEmpty
        let canonicalName = sanitize(
            bundleId ?? source.deletingPathExtension().lastPathComponent
        )

        let fm = FileManager.default
        try fm.createDirectory(at: PluginPaths.root, withIntermediateDirectories: true)

        let existing = bundleId.flatMap { PluginManifestLocator.findExistingInstall(bundleId: $0) }
        let folderName = existing?.lastPathComponent ?? canonicalName
        let target = PluginPaths.root.appendingPathComponent(folderName, isDirectory: true)

        if fm.fileExists(atPath: target.path) {
            guard replaceExisting else {
                throw ImportError.alreadyExists(
                    bundleId: bundleId ?? folderName,
                    folderName: folderName
                )
            }
            try fm.removeItem(at: target)
        }

        do {
            try fm.moveItem(at: pluginRoot, to: target)
        } catch {
            throw ImportError.copyFailed(detail: (error as NSError).localizedDescription)
        }

        return ImportResult(
            installedAt: target,
            bundleId: bundleId ?? folderName,
            displayName: manifest.name ?? folderName
        )
    }

    private static func sanitize(_ name: String) -> String {
        let allowed = CharacterSet.alphanumerics
            .union(CharacterSet(charactersIn: "._-"))
        let scalars = name.unicodeScalars.map {
            allowed.contains($0) ? Character($0) : "-"
        }
        let trimmed = String(scalars).trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return trimmed.isEmpty ? "plugin-\(UUID().uuidString.prefix(8))" : trimmed
    }
}
