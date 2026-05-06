//
//  LayoutStore.swift
//  ActivateDock
//

import Cocoa

struct PersistedGroup: Codable {
    let title: String
    let colorRGBA: [Double]
    let bundleIdentifiers: [String]
}

enum LayoutStore {
    private static let key = "ActivateDock.Layout.v1"

    static func load() -> [PersistedGroup]? {
        guard let data = UserDefaults.standard.data(forKey: key),
              let groups = try? JSONDecoder().decode([PersistedGroup].self, from: data),
              !groups.isEmpty else { return nil }
        return groups
    }

    static func save(_ groups: [PersistedGroup]) {
        guard let data = try? JSONEncoder().encode(groups) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    static func encode(group: AppGroup) -> PersistedGroup {
        let c = group.accentColor.usingColorSpace(.sRGB) ?? NSColor.systemGray.usingColorSpace(.sRGB)!
        return PersistedGroup(
            title: group.title,
            colorRGBA: [Double(c.redComponent), Double(c.greenComponent), Double(c.blueComponent), Double(c.alphaComponent)],
            bundleIdentifiers: group.items.map { $0.bundleIdentifier }
        )
    }

    static func color(from components: [Double]) -> NSColor {
        guard components.count >= 4 else { return .systemGray }
        return NSColor(srgbRed: CGFloat(components[0]),
                       green: CGFloat(components[1]),
                       blue: CGFloat(components[2]),
                       alpha: CGFloat(components[3]))
    }
}
