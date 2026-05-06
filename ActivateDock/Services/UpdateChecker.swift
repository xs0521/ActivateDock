//
//  UpdateChecker.swift
//  ActivateDock
//

import Foundation

enum UpdateCheckResult {
    case upToDate(current: String)
    case available(latest: String, current: String, url: URL)
    case noReleaseYet
    case rateLimited
    case failed(Error)
}

final class UpdateChecker {
    static let shared = UpdateChecker()

    private let owner = "xs0521"
    private let repo = "ActivateDock"

    var releasesPageURL: URL {
        URL(string: "https://github.com/\(owner)/\(repo)/releases")!
    }

    func check(completion: @escaping (UpdateCheckResult) -> Void) {
        let endpoint = "https://api.github.com/repos/\(owner)/\(repo)/releases/latest"
        guard let url = URL(string: endpoint) else {
            DispatchQueue.main.async {
                completion(.failed(Self.makeError("Invalid endpoint")))
            }
            return
        }
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("ActivateDock", forHTTPHeaderField: "User-Agent")

        URLSession.shared.dataTask(with: request) { data, response, error in
            let result = Self.parse(data: data, response: response, error: error)
            DispatchQueue.main.async { completion(result) }
        }.resume()
    }

    private static func parse(data: Data?, response: URLResponse?, error: Error?) -> UpdateCheckResult {
        if let error { return .failed(error) }
        guard let http = response as? HTTPURLResponse else {
            return .failed(makeError("No HTTP response"))
        }
        
        if http.statusCode == 404 { return .noReleaseYet }
        if http.statusCode == 403 { return .rateLimited }
        guard http.statusCode == 200, let data else {
            return .failed(makeError("GitHub responded with status \(http.statusCode)"))
        }
        do {
            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            guard let urlString = release.html_url, let url = URL(string: urlString) else {
                return .failed(makeError("Release missing html_url"))
            }
            let latest = normalize(release.tag_name)
            let current = currentVersion()
            return compare(latest: latest, current: current) > 0
                ? .available(latest: latest, current: current, url: url)
                : .upToDate(current: current)
        } catch let decodeError {
            return .failed(decodeError)
        }
    }

    private static func currentVersion() -> String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0.0.0"
    }

    private static func normalize(_ tag: String) -> String {
        tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
    }

    private static func compare(latest: String, current: String) -> Int {
        let l = latest.split(separator: ".").compactMap { Int($0) }
        let c = current.split(separator: ".").compactMap { Int($0) }
        let count = max(l.count, c.count)
        for i in 0..<count {
            let a = i < l.count ? l[i] : 0
            let b = i < c.count ? c[i] : 0
            if a > b { return 1 }
            if a < b { return -1 }
        }
        return 0
    }

    private static func makeError(_ message: String) -> NSError {
        NSError(domain: "UpdateChecker", code: -1,
                userInfo: [NSLocalizedDescriptionKey: message])
    }
}

private struct GitHubRelease: Decodable {
    let tag_name: String
    let html_url: String?
}
