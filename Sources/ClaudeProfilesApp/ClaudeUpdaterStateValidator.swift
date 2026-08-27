import ClaudeProfilesCore
import Foundation

struct ClaudeUpdaterStateValidator {
    static func isSafe(_ data: Data, homeURL: URL, managedRootURL: URL) -> Bool {
        guard let targetValue = dictionary(in: data)?["targetBundleURL"] as? String,
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

    private static func dictionary(in data: Data) -> [String: Any]? {
        if let value = try? PropertyListSerialization.propertyList(from: data, format: nil)
            as? [String: Any] {
            return value
        }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }
}
