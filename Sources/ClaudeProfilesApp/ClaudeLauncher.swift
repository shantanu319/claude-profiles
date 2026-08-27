import AppKit
import ClaudeProfilesCore
import Foundation

enum ClaudeLauncherError: LocalizedError {
    case couldNotActivate
    case legacyInstanceRunning
    case substitutedApplication

    var errorDescription: String? {
        switch self {
        case .couldNotActivate:
            "Claude is open, but macOS could not bring its window forward."
        case .legacyInstanceRunning:
            "This profile is still open through the old shared Claude app. Quit that Claude "
                + "app with ⌘Q, then open the profile again. Its data will be preserved."
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
    private var sourceWasVerified = false
    private var verifiedSourceVersion: String?

    init(
        locator: ClaudeInstallationLocator = ClaudeInstallationLocator(),
        repository: ProfileRepository
    ) {
        self.locator = locator
        self.repository = repository
        self.cloneManager = ClaudeCloneManager(paths: repository.paths)
    }

    func preflight() async throws {
        _ = try await verifiedInstallation()
    }

    func runningProcesses(for profiles: [ClaudeProfile]) throws -> [ClaudeProcess] {
        var executablePaths = Set(
            profiles.map { repository.paths.appExecutableURL(for: $0).path }
        )
        if let source = try? installation() {
            executablePaths.insert(source.executableURL.path)
        } else {
            executablePaths.insert("/Applications/Claude.app/Contents/MacOS/Claude")
            executablePaths.insert(
                FileManager.default.homeDirectoryForCurrentUser
                    .appending(path: "Applications/Claude.app/Contents/MacOS/Claude").path
            )
        }
        return try ClaudeProcessScanner(executablePaths: executablePaths).snapshot()
    }

    func process(for profile: ClaudeProfile?, in processes: [ClaudeProcess]) -> ClaudeProcess? {
        processes.first { process in
            if let profile {
                let clonePath = repository.paths.appExecutableURL(for: profile).path
                let dataPath = repository.paths.userDataURL(for: profile).path
                return normalized(process.executablePath) == normalized(clonePath)
                    || normalized(process.userDataPath) == normalized(dataPath)
            }
            var knownStandardPaths: Set<String> = [
                "/Applications/Claude.app/Contents/MacOS/Claude",
                FileManager.default.homeDirectoryForCurrentUser
                    .appending(path: "Applications/Claude.app/Contents/MacOS/Claude").path,
            ]
            if let cachedPath = cachedInstallation?.executableURL.path {
                knownStandardPaths.insert(cachedPath)
            }
            guard knownStandardPaths.contains(process.executablePath) else {
                return false
            }
            guard let dataPath = process.userDataPath else { return true }
            return normalized(dataPath) == normalized(repository.paths.standardUserDataURL.path)
        }
    }

    func isLegacy(_ process: ClaudeProcess, for profile: ClaudeProfile) -> Bool {
        normalized(process.executablePath) != normalized(
            repository.paths.appExecutableURL(for: profile).path
        )
    }

    func open(_ profile: ClaudeProfile?, among profiles: [ClaudeProfile]) async throws {
        if let running = process(for: profile, in: try runningProcesses(for: profiles)) {
            if let profile, isLegacy(running, for: profile) {
                throw ClaudeLauncherError.legacyInstanceRunning
            }
            guard let application = NSRunningApplication(processIdentifier: running.pid),
                  application.activate(options: [.activateAllWindows]) else {
                throw ClaudeLauncherError.couldNotActivate
            }
            return
        }
        let verifiedSource = try await verifiedInstallation()

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
            target = try await cloneManager.prepare(profile: profile, from: verifiedSource)
        } else {
            target = verifiedSource
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

    private func verifiedInstallation() async throws -> ClaudeInstallation {
        let value = try installation()
        let version = ClaudeBundleMetadata.version(at: value.appURL)
        if !sourceWasVerified || verifiedSourceVersion != version {
            let appURL = value.appURL
            try await Task.detached(priority: .userInitiated) {
                try ClaudeSignatureVerifier().verify(appURL)
            }.value
            sourceWasVerified = true
            verifiedSourceVersion = version
        }
        return value
    }
}
