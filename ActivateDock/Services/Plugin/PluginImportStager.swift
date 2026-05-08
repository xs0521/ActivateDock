//
//  PluginImportStager.swift
//  ActivateDock
//

import Foundation

enum PluginImportStager {

    struct Staged {
        let tempRoot: URL
        let contentRoot: URL
    }

    static func stage(_ source: URL) throws -> Staged {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: source.path, isDirectory: &isDir) else {
            throw PluginImporter.ImportError.unsupportedFile
        }

        let temp = fm.temporaryDirectory.appendingPathComponent(
            "ActivateDock-import-\(UUID().uuidString)",
            isDirectory: true
        )
        try fm.createDirectory(at: temp, withIntermediateDirectories: true)

        if isDir.boolValue {
            return try copyDirectory(source, into: temp)
        }

        let ext = source.pathExtension.lowercased()
        guard ext == "zip" || ext == "alfredworkflow" else {
            try? fm.removeItem(at: temp)
            throw PluginImporter.ImportError.unsupportedFile
        }
        try unzip(source: source, into: temp)
        return Staged(tempRoot: temp, contentRoot: temp)
    }

    private static func copyDirectory(_ source: URL, into temp: URL) throws -> Staged {
        let dest = temp.appendingPathComponent(source.lastPathComponent, isDirectory: true)
        do {
            try FileManager.default.copyItem(at: source, to: dest)
        } catch {
            try? FileManager.default.removeItem(at: temp)
            throw PluginImporter.ImportError.copyFailed(
                detail: (error as NSError).localizedDescription
            )
        }
        return Staged(tempRoot: temp, contentRoot: dest)
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
            throw PluginImporter.ImportError.unzipFailed(
                detail: (error as NSError).localizedDescription
            )
        }

        guard process.terminationStatus == 0 else {
            let data = stderr.fileHandleForReading.readDataToEndOfFile()
            let detail = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .nonEmpty ?? "exit status \(process.terminationStatus)"
            try? FileManager.default.removeItem(at: directory)
            throw PluginImporter.ImportError.unzipFailed(detail: detail)
        }
    }
}

extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
