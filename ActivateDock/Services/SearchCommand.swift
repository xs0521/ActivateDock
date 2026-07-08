//
//  SearchCommand.swift
//  ActivateDock
//

import Foundation

struct SearchCommand {
    let url: URL

    static func parse(_ input: String) -> SearchCommand? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let spaceIndex = trimmed.firstIndex(of: " ") else { return nil }

        let keyword = trimmed[..<spaceIndex].lowercased()
        guard let template = registry[String(keyword)] else { return nil }

        let argument = trimmed[trimmed.index(after: spaceIndex)...]
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !argument.isEmpty,
              let encoded = argument.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: template.replacingOccurrences(of: "{query}", with: encoded))
        else { return nil }

        return SearchCommand(url: url)
    }

    static func hint(for input: String) -> String? {
        guard let spaceIndex = input.firstIndex(of: " ") else { return nil }
        let keyword = input[..<spaceIndex].lowercased()
        guard hintRegistry.contains(String(keyword)) else { return nil }
        let suffix = input[input.index(after: spaceIndex)...]
        guard suffix.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return L("search.hint.web_query")
    }

    private static let registry: [String: String] = [
        "google": "https://www.google.com/search?q={query}",
        "baidu": "https://www.baidu.com/s?wd={query}",
        "bing": "https://www.bing.com/search?q={query}"
    ]

    private static let hintRegistry: Set<String> = ["google", "baidu", "bing"]
}
