//
//  LocalizationManager.swift
//  ActivateDock
//
//  Runtime-switchable localization. Picks an .lproj bundle based on the
//  user's saved preference (zh-Hans / en); broadcasts didChangeNotification
//  so live UI can rebuild itself when the user flips languages from
//  Settings without relaunching the app.
//

import Foundation

enum AppLanguage: String, CaseIterable {
    case english = "en"
    case simplifiedChinese = "zh-Hans"

    var displayName: String {
        switch self {
        case .english: return "English"
        case .simplifiedChinese: return "中文"
        }
    }

    static var systemDefault: AppLanguage {
        for code in Locale.preferredLanguages {
            let lower = code.lowercased()
            if lower.hasPrefix("zh") { return .simplifiedChinese }
            if lower.hasPrefix("en") { return .english }
        }
        return .english
    }
}

final class LocalizationManager {
    static let shared = LocalizationManager()
    static let didChangeNotification = Notification.Name("ActivateDock.LocalizationDidChange")

    private static let preferenceKey = "ActivateDock.AppLanguage"

    private(set) var currentLanguage: AppLanguage
    private var bundle: Bundle

    private init() {
        let stored = UserDefaults.standard.string(forKey: Self.preferenceKey)
        let lang = stored.flatMap(AppLanguage.init(rawValue:)) ?? .systemDefault
        self.currentLanguage = lang
        self.bundle = Self.makeBundle(for: lang)
    }

    func setLanguage(_ lang: AppLanguage) {
        guard lang != currentLanguage else { return }
        currentLanguage = lang
        bundle = Self.makeBundle(for: lang)
        UserDefaults.standard.set(lang.rawValue, forKey: Self.preferenceKey)
        NotificationCenter.default.post(name: Self.didChangeNotification, object: nil)
    }

    func string(forKey key: String) -> String {
        bundle.localizedString(forKey: key, value: key, table: nil)
    }

    private static func makeBundle(for lang: AppLanguage) -> Bundle {
        if let path = Bundle.main.path(forResource: lang.rawValue, ofType: "lproj"),
           let b = Bundle(path: path) {
            return b
        }
        return Bundle.main
    }
}

@inline(__always)
func L(_ key: String) -> String {
    LocalizationManager.shared.string(forKey: key)
}

func L(_ key: String, _ args: CVarArg...) -> String {
    let format = LocalizationManager.shared.string(forKey: key)
    return String(format: format, locale: Locale.current, arguments: args)
}
