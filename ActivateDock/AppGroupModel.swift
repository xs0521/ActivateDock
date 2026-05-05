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
        var groups: [AppGroup] = [
            AppGroup(title: "即时通信", accentColor: .systemPurple, items: []),
            AppGroup(title: "编程软件", accentColor: .systemBlue, items: []),
            AppGroup(title: "浏览器", accentColor: .systemGreen, items: []),
            AppGroup(title: "设计工具", accentColor: .systemPink, items: []),
            AppGroup(title: "其他", accentColor: .systemGray, items: [])
        ]

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

        return groups.filter { !$0.items.isEmpty }
    }

    private static func matches(_ name: String, _ bundle: String, _ keys: [String]) -> Bool {
        keys.contains { name.contains($0) || bundle.contains($0) }
    }
}
