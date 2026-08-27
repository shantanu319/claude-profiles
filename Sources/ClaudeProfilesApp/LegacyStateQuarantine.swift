import ClaudeProfilesCore
import Foundation

struct LegacyStateQuarantine {
    let paths: ProfilePaths
    var fileManager = FileManager.default

    func needsRun(for profile: ClaudeProfile) -> Bool {
        let container = paths.containerURL(for: profile)
        guard !fileManager.fileExists(
            atPath: container.appending(path: ".code-isolation-v1").path
        ) else { return false }
        let userData = paths.userDataURL(for: profile)
        return stateNames.contains {
            fileManager.fileExists(atPath: userData.appending(path: $0).path)
        }
    }

    func runOnce(for profile: ClaudeProfile) throws {
        let container = paths.containerURL(for: profile)
        let receipt = container.appending(path: ".code-isolation-v1")
        guard !fileManager.fileExists(atPath: receipt.path) else { return }

        let userData = paths.userDataURL(for: profile)
        let existing = stateNames.filter {
            fileManager.fileExists(atPath: userData.appending(path: $0).path)
        }
        if !existing.isEmpty {
            let backup = backupURL(for: profile)
            try fileManager.createDirectory(
                at: backup,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
            try writeExplanationIfNeeded(to: backup)
            for name in existing {
                let destination = availableDestination(named: name, in: backup)
                try fileManager.moveItem(
                    at: userData.appending(path: name),
                    to: destination
                )
            }
        }
        if fileManager.fileExists(atPath: backupURL(for: profile).path) {
            try Data().write(to: pendingNoticeURL(for: profile), options: .atomic)
        }
        try Data().write(to: receipt, options: .atomic)
        try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: receipt.path)
    }

    func backupURL(for profile: ClaudeProfile) -> URL {
        paths.containerURL(for: profile).appending(
            path: "Legacy Shared Session Indexes",
            directoryHint: .isDirectory
        )
    }

    func hasPendingNotice(for profile: ClaudeProfile) -> Bool {
        fileManager.fileExists(atPath: pendingNoticeURL(for: profile).path)
    }

    func markNoticeShown(for profile: ClaudeProfile) throws {
        let url = pendingNoticeURL(for: profile)
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }

    private func availableDestination(named name: String, in directory: URL) -> URL {
        var destination = directory.appending(path: name)
        var suffix = 2
        while fileManager.fileExists(atPath: destination.path) {
            destination = directory.appending(path: "\(name)-\(suffix)")
            suffix += 1
        }
        return destination
    }

    private func writeExplanationIfNeeded(to directory: URL) throws {
        let url = directory.appending(path: "README.txt")
        guard !fileManager.fileExists(atPath: url.path) else { return }
        let message = "Claude Profiles backed up these mixed local session indexes before "
            + "isolating this profile. Global transcripts were not moved or deleted.\n"
        try Data(message.utf8).write(to: url, options: .atomic)
    }

    private func pendingNoticeURL(for profile: ClaudeProfile) -> URL {
        paths.containerURL(for: profile).appending(path: ".code-isolation-notice-pending")
    }

    private var stateNames: [String] {
        ["claude-code-sessions", "local-agent-mode-sessions"]
    }
}
