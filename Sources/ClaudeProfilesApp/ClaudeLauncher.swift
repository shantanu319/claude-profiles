import AppKit
import ClaudeProfilesCore
import Foundation

enum ClaudeLauncherError: LocalizedError {
    case couldNotActivate

    var errorDescription: String? {
        "Claude is running, but macOS could not bring its window forward."
    }
}

@MainActor
final class ClaudeLauncher {
    private let locator: ClaudeInstallationLocator
    private let repository: ProfileRepository

    init(
        locator: ClaudeInstallationLocator = ClaudeInstallationLocator(),
        repository: ProfileRepository
    ) {
        self.locator = locator
        self.repository = repository
    }

    func runningProcesses() throws -> [ClaudeProcess] {
        let installation = try locator.locate()
        return try ClaudeProcessScanner(executablePath: installation.executableURL.path).snapshot()
    }

    func process(for profile: ClaudeProfile?, in processes: [ClaudeProcess]) -> ClaudeProcess? {
        processes.first { process in
            if let profile {
                return normalized(process.userDataPath) == normalized(
                    repository.paths.userDataURL(for: profile).path
                )
            }
            guard let dataPath = process.userDataPath else { return true }
            return normalized(dataPath) == normalized(repository.paths.standardUserDataURL.path)
        }
    }

    func open(_ profile: ClaudeProfile?) async throws {
        let installation = try locator.locate()
        let scanner = ClaudeProcessScanner(executablePath: installation.executableURL.path)
        if let running = process(for: profile, in: try scanner.snapshot()) {
            guard let application = NSRunningApplication(processIdentifier: running.pid),
                  application.activate(options: [.activateAllWindows]) else {
                throw ClaudeLauncherError.couldNotActivate
            }
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.addsToRecentItems = false
        configuration.createsNewApplicationInstance = true
        if let profile {
            try repository.ensureDirectories(for: profile)
            let dataPath = repository.paths.userDataURL(for: profile).path
            configuration.arguments = ["--user-data-dir=\(dataPath)"]
        }

        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Void, Error>) in
            NSWorkspace.shared.openApplication(
                at: installation.appURL,
                configuration: configuration
            ) { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    func reveal(_ profile: ClaudeProfile?) {
        let url = profile.map(repository.paths.userDataURL)
            ?? repository.paths.standardUserDataURL
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    private func normalized(_ path: String?) -> String? {
        path.map { URL(fileURLWithPath: $0).standardizedFileURL.path }
    }
}
