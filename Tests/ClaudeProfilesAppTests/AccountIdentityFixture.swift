import Foundation
@testable import ClaudeProfilesApp

struct Fixture {
    let rootURL: URL
    let targetURL: URL
    let canonicalURL: URL
    let profileID = UUID()

    init() throws {
        rootURL = FileManager.default.temporaryDirectory.appending(
            path: "ClaudeAccountCollisionGuardTests-\(UUID().uuidString)"
        )
        targetURL = rootURL.appending(path: "managed", directoryHint: .isDirectory)
        canonicalURL = rootURL.appending(path: "canonical", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: targetURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: canonicalURL, withIntermediateDirectories: true)
    }

    var target: ClaudeAccountLocation {
        ClaudeAccountLocation(profileID: profileID, displayName: "Work", userDataURL: targetURL)
    }

    var canonical: ClaudeAccountLocation {
        ClaudeAccountLocation(
            profileID: nil,
            displayName: "Existing Claude",
            userDataURL: canonicalURL
        )
    }

    func writeConfig(account: String, to directory: URL) throws {
        let data = try JSONSerialization.data(withJSONObject: [
            "lastKnownAccountUuid": account,
            "oauth:tokenCache": "must-not-be-read",
        ])
        try data.write(to: directory.appending(path: "config.json"))
    }

    func remove() {
        try? FileManager.default.removeItem(at: rootURL)
    }
}
