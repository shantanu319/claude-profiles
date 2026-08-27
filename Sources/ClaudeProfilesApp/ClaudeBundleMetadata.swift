import Foundation

enum ClaudeBundleMetadata {
    static func installation(at appURL: URL) -> ClaudeInstallation {
        ClaudeInstallation(
            appURL: appURL,
            executableURL: appURL.appending(path: "Contents/MacOS/Claude")
        )
    }

    static func version(at appURL: URL) -> String? {
        let plistURL = appURL.appending(path: "Contents/Info.plist")
        guard let data = try? Data(contentsOf: plistURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil),
              let dictionary = plist as? [String: Any] else {
            return nil
        }
        return dictionary["CFBundleVersion"] as? String
    }
}
