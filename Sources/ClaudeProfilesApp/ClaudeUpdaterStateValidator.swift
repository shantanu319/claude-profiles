import ClaudeProfilesCore
import Foundation

struct ClaudeUpdaterStateValidator {
    static func isSafe(_ data: Data, homeURL: URL, managedRootURL: URL) -> Bool {
        guard let values = try? PropertyListSerialization.propertyList(
            from: data,
            format: nil
        ) as? [String: Any],
        let targetValue = values["targetBundleURL"] as? String,
        let targetURL = URL(string: targetValue), targetURL.isFileURL else {
            return false
        }
        guard let targetPath = CanonicalFilePath.existing(targetURL) else { return false }
        let managedRootPath = CanonicalFilePath.resolve(managedRootURL)
        guard targetPath != managedRootPath,
              !targetPath.hasPrefix(managedRootPath + "/") else {
            return false
        }
        let allowed = [
            URL(fileURLWithPath: "/Applications/Claude.app"),
            homeURL.appending(path: "Applications/Claude.app"),
        ].map(CanonicalFilePath.resolve)
        return allowed.contains(targetPath)
    }
}
