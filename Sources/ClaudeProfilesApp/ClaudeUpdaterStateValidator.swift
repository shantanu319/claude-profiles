import Foundation

struct ClaudeUpdaterStateValidator {
    static func isSafe(_ data: Data, homeURL: URL) -> Bool {
        guard let values = try? PropertyListSerialization.propertyList(
            from: data,
            format: nil
        ) as? [String: Any],
        let targetValue = values["targetBundleURL"] as? String,
        let targetURL = URL(string: targetValue), targetURL.isFileURL else {
            return false
        }
        let allowed = [
            URL(fileURLWithPath: "/Applications/Claude.app"),
            homeURL.appending(path: "Applications/Claude.app"),
        ].map(canonicalPath)
        return allowed.contains(canonicalPath(targetURL))
    }

    private static func canonicalPath(_ url: URL) -> String {
        (try? url.resourceValues(forKeys: [.canonicalPathKey]).canonicalPath)
            ?? url.standardizedFileURL.path
    }
}
