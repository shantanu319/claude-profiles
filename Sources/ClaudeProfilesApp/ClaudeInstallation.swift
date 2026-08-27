import AppKit
import Foundation

struct ClaudeInstallation: Sendable {
    let appURL: URL
    let executableURL: URL
}

enum ClaudeInstallationError: LocalizedError {
    case notFound
    case invalidBundle

    var errorDescription: String? {
        switch self {
        case .notFound:
            "Claude Desktop is not installed in Applications."
        case .invalidBundle:
            "The installed Claude application is incomplete or unrecognized."
        }
    }
}

@MainActor
struct ClaudeInstallationLocator {
    private let bundleIdentifier = "com.anthropic.claudefordesktop"

    func locate() throws -> ClaudeInstallation {
        let homeApplications = FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "Applications/Claude.app", directoryHint: .isDirectory)
        let known = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)
        let candidates = [
            URL(fileURLWithPath: "/Applications/Claude.app", isDirectory: true),
            homeApplications,
            known,
        ].compactMap { $0 }

        guard let appURL = candidates.first(where: isClaudeBundle) else {
            throw ClaudeInstallationError.notFound
        }
        let executableURL = appURL.appending(path: "Contents/MacOS/Claude")
        guard FileManager.default.isExecutableFile(atPath: executableURL.path) else {
            throw ClaudeInstallationError.invalidBundle
        }
        return ClaudeInstallation(appURL: appURL, executableURL: executableURL)
    }

    private func isClaudeBundle(_ url: URL) -> Bool {
        Bundle(url: url)?.bundleIdentifier == bundleIdentifier
    }
}
