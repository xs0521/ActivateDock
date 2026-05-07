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
                return "只支持 .alfredworkflow / .zip 文件或一个插件目录。"
            case .unzipFailed(let detail):
                return "解压失败:\(detail)"
            case .missingManifest:
                return "找不到 info.plist —— 这不像是一个 Alfred 插件。"
            case .manifestDecodeFailed(let detail):
                return "info.plist 解析失败:\(detail)"
            case .alreadyExists(let bundleId, _):
                return "插件 \(bundleId) 已存在。"
            case .copyFailed(let detail):
                return "拷贝失败:\(detail)"
            }
        }
    }

    static func install(from source: URL, replaceExisting: Bool) throws -> ImportResult {
        let staged = try stageSource(source)
        defer { try? FileManager.default.removeItem(at: staged.tempRoot) }

        let pluginRoot = try locatePluginRoot(in: staged.contentRoot)
        let manifest = try parseManifest(at: pluginRoot)

        let bundleId = manifest.bundleid?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nonEmpty
        let canonicalName = sanitize(
            bundleId ?? source.deletingPathExtension().lastPathComponent
        )

        let fm = FileManager.default
        try fm.createDirectory(at: PluginPaths.root, withIntermediateDirectories: true)

        let existing = bundleId.flatMap { findExistingInstall(bundleId: $0) }
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

    private struct Staged {
        let tempRoot: URL
        let contentRoot: URL
    }

    private static func stageSource(_ source: URL) throws -> Staged {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: source.path, isDirectory: &isDir) else {
            throw ImportError.unsupportedFile
        }
        let temp = fm.temporaryDirectory.appendingPathComponent(
            "ActivateDock-import-\(UUID().uuidString)",
            isDirectory: true
        )
        try fm.createDirectory(at: temp, withIntermediateDirectories: true)

        if isDir.boolValue {
            let dest = temp.appendingPathComponent(source.lastPathComponent, isDirectory: true)
            do {
                try fm.copyItem(at: source, to: dest)
            } catch {
                try? fm.removeItem(at: temp)
                throw ImportError.copyFailed(detail: (error as NSError).localizedDescription)
            }
            return Staged(tempRoot: temp, contentRoot: dest)
        }

        let ext = source.pathExtension.lowercased()
        guard ext == "zip" || ext == "alfredworkflow" else {
            try? fm.removeItem(at: temp)
            throw ImportError.unsupportedFile
        }
        try unzip(source: source, into: temp)
        return Staged(tempRoot: temp, contentRoot: temp)
    }

    private static func unzip(source: URL, into directory: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-q", source.path, "-d", directory.path]
        let stderr = Pipe()
        process.standardError = stderr
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            try? FileManager.default.removeItem(at: directory)
            throw ImportError.unzipFailed(detail: (error as NSError).localizedDescription)
        }
        guard process.terminationStatus == 0 else {
            let data = stderr.fileHandleForReading.readDataToEndOfFile()
            let detail = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .nonEmpty ?? "exit status \(process.terminationStatus)"
            try? FileManager.default.removeItem(at: directory)
            throw ImportError.unzipFailed(detail: detail)
        }
    }

    private static func locatePluginRoot(in dir: URL) throws -> URL {
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
            let isDir = (try? entry.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            guard isDir else { continue }
            if fm.fileExists(atPath: entry.appendingPathComponent("info.plist").path) {
                return entry
            }
        }
        throw ImportError.missingManifest
    }

    private static func parseManifest(at dir: URL) throws -> AlfredWorkflowManifest {
        let plistURL = dir.appendingPathComponent("info.plist")
        do {
            let data = try Data(contentsOf: plistURL)
            return try PropertyListDecoder().decode(AlfredWorkflowManifest.self, from: data)
        } catch {
            throw ImportError.manifestDecodeFailed(detail: (error as NSError).localizedDescription)
        }
    }

    private static func findExistingInstall(bundleId: String) -> URL? {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(
            at: PluginPaths.root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }
        for entry in entries {
            let plistURL = entry.appendingPathComponent("info.plist")
            guard let data = try? Data(contentsOf: plistURL),
                  let m = try? PropertyListDecoder().decode(AlfredWorkflowManifest.self, from: data),
                  m.bundleid == bundleId
            else { continue }
            return entry
        }
        return nil
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

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
