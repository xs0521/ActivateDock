//
//  AppGroupModel.swift
//  ActivateDock
//

import Cocoa

struct RunningApp {
    let app: NSRunningApplication
    let displayName: String
    let bundleIdentifier: String
}

struct AppGroup {
    let title: String
    let accentColor: NSColor
    var items: [RunningApp]
}

enum AppGroupBuilder {
    static func build(from apps: [RunningApp]) -> [AppGroup] {
        let groups: [AppGroup]
        if let saved = LayoutStore.load() {
            groups = reconcile(saved: saved, with: apps)
        } else {
            groups = defaultGroups(from: apps)
        }
        return groups.filter { !$0.items.isEmpty }
    }

    private static func reconcile(saved: [PersistedGroup], with apps: [RunningApp]) -> [AppGroup] {
        var byBundle: [String: RunningApp] = [:]
        for app in apps { byBundle[app.bundleIdentifier] = app }

        var groups: [AppGroup] = []
        for s in saved {
            var items: [RunningApp] = []
            for bid in s.bundleIdentifiers {
                if let app = byBundle.removeValue(forKey: bid) {
                    items.append(app)
                }
            }
            groups.append(AppGroup(title: s.title, accentColor: LayoutStore.color(from: s.colorRGBA), items: items))
        }

        let remaining = Array(byBundle.values).sorted { $0.displayName < $1.displayName }
        for dg in defaultGroups(from: remaining) where !dg.items.isEmpty {
            if let idx = groups.firstIndex(where: { $0.title == dg.title }) {
                groups[idx].items.append(contentsOf: dg.items)
            } else {
                let used = Set(groups.map { $0.accentColor })
                let recolored = AppGroup(
                    title: dg.title,
                    accentColor: AccentPalette.nextColor(excluding: used),
                    items: dg.items
                )
                let insertAt = groups.firstIndex(where: { $0.title == "其他" }) ?? groups.count
                groups.insert(recolored, at: insertAt)
            }
        }
        return groups
    }

    private static func defaultGroups(from apps: [RunningApp]) -> [AppGroup] {
        let titles = ["即时通信", "编程软件", "浏览器", "设计工具", "其他"]
        let colors = AccentPalette.uniqueColors(count: titles.count)
        var groups: [AppGroup] = zip(titles, colors).map {
            AppGroup(title: $0, accentColor: $1, items: [])
        }

        for app in apps {
            let name = app.displayName.lowercased()
            let bundle = app.bundleIdentifier.lowercased()

            if matches(name, bundle, ["wechat", "slack", "telegram", "discord", "dingtalk", "钉钉", "企业微信", "qq", "message", "messages"]) {
                groups[0].items.append(app)
            } else if matches(name, bundle, ["xcode", "cursor", "code", "terminal", "iterm", "android studio", "sublime", "nova", "warp", "kitty", "jetbrains", "goland", "pycharm", "intellij"]) {
                groups[1].items.append(app)
            } else if matches(name, bundle, ["chrome", "safari", "edge", "firefox", "arc", "brave", "browser", "浏览器"]) {
                groups[2].items.append(app)
            } else if matches(name, bundle, ["figma", "photoshop", "illustrator", "sketch", "design", "pixelmator", "canva"]) {
                groups[3].items.append(app)
            } else {
                groups[4].items.append(app)
            }
        }

        return groups
    }

    private static func matches(_ name: String, _ bundle: String, _ keys: [String]) -> Bool {
        keys.contains { name.contains($0) || bundle.contains($0) }
    }
}
