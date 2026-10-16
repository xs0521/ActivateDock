import Foundation

enum PluginRemover {
    enum RemovalError: LocalizedError {
        case outsidePluginRoot

        var errorDescription: String? {
            L("plugins.delete.error.invalid_directory")
        }
    }

    static func remove(at directory: URL, root: URL = PluginPaths.root) throws {
        let root = root.standardizedFileURL.resolvingSymlinksInPath()
        let directory = directory.standardizedFileURL
        // Only remove a direct installation child, never the root or an external target.
        guard directory.deletingLastPathComponent().resolvingSymlinksInPath() == root,
              directory.resolvingSymlinksInPath().deletingLastPathComponent() == root else {
            throw RemovalError.outsidePluginRoot
        }
        try FileManager.default.removeItem(at: directory)
    }
}
