import AppKit
import ClaudeProfilesCore
import Foundation

enum ClaudeLauncherError: LocalizedError {
    case couldNotActivate
    case substitutedApplication

    var errorDescription: String? {
        switch self {
        case .couldNotActivate:
            "Claude is open, but macOS could not bring its window forward."
        case .substitutedApplication:
            "macOS opened a different Claude app. Quit every Claude app and try again."
        }
    }
}

@MainActor
final class ClaudeLauncher {
    private let locator: ClaudeInstallationLocator
    private let repository: ProfileRepository
    private let cloneManager: ClaudeCloneManager
    private var cachedInstallation: ClaudeInstallation?

    init(
        locator: ClaudeInstallationLocator = ClaudeInstallationLocator(),
        repository: ProfileRepository
    ) {
        self.locator = locator
        self.repository = repository
        self.cloneManager = ClaudeCloneManager(paths: repository.paths)
    }

    func preflight() throws {
        _ = try installation()
    }

    func runningProcesses(for profiles: [ClaudeProfile]) throws -> [ClaudeProcess] {
        let source = try installation()
        let clonePaths = profiles.map { repository.paths.appExecutableURL(for: $0).path }
        return try ClaudeProcessScanner(
            executablePaths: Set(clonePaths + [source.executableURL.path])
        ).snapshot()
    }

    func process(for profile: ClaudeProfile?, in processes: [ClaudeProcess]) -> ClaudeProcess? {
        processes.first { process in
            if let profile {
                let clonePath = repository.paths.appExecutableURL(for: profile).path
                let dataPath = repository.paths.userDataURL(for: profile).path
                return normalized(process.executablePath) == normalized(clonePath)
                    || normalized(process.userDataPath) == normalized(dataPath)
            }
            guard process.executablePath == cachedInstallation?.executableURL.path else {
                return false
            }
            guard let dataPath = process.userDataPath else { return true }
            return normalized(dataPath) == normalized(repository.paths.standardUserDataURL.path)
        }
    }

    func open(_ profile: ClaudeProfile?, among profiles: [ClaudeProfile]) async throws {
        let source = try installation()
        if let running = process(for: profile, in: try runningProcesses(for: profiles)) {
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
        configuration.allowsRunningApplicationSubstitution = false
        let target: ClaudeInstallation
        if let profile {
            try repository.ensureDirectories(for: profile)
            let dataPath = repository.paths.userDataURL(for: profile).path
            configuration.arguments = ["--user-data-dir=\(dataPath)"]
            target = try await cloneManager.prepare(profile: profile, from: source)
        } else {
            target = source
        }

        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Void, Error>) in
            NSWorkspace.shared.openApplication(
                at: target.appURL,
                configuration: configuration
            ) { application, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if application?.executableURL?.standardizedFileURL
                    != target.executableURL.standardizedFileURL {
                    continuation.resume(throwing: ClaudeLauncherError.substitutedApplication)
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

    private func installation() throws -> ClaudeInstallation {
        if let cachedInstallation { return cachedInstallation }
        let value = try locator.locate()
        cachedInstallation = value
        return value
    }
}
