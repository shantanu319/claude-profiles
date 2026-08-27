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
            "This Claude window is not using the profile's exact app and storage pair. Quit it "
                + "with ⌘Q, then open the profile again. Its data will be preserved."
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
    private let legacyStateQuarantine: LegacyStateQuarantine
    private let updaterPolicy: ClaudeUpdaterPolicy
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
        self.legacyStateQuarantine = LegacyStateQuarantine(paths: repository.paths)
        self.updaterPolicy = ClaudeUpdaterPolicy(paths: repository.paths)
    }

    func preflight() async throws {
        _ = try await verifiedInstallation()
    }

    func runningProcesses(for profiles: [ClaudeProfile]) throws -> [ClaudeProcess] {
        var executablePaths = Set(
            profiles.map { repository.paths.appExecutableURL(for: $0).path }
        )
        executablePaths.insert("/Applications/Claude.app/Contents/MacOS/Claude")
        executablePaths.insert(
            FileManager.default.homeDirectoryForCurrentUser
                .appending(path: "Applications/Claude.app/Contents/MacOS/Claude").path
        )
        if let source = try? installation() {
            executablePaths.insert(source.executableURL.path)
        }
        return try ClaudeProcessScanner(executablePaths: executablePaths).snapshot()
    }

    func process(for profile: ClaudeProfile?, in processes: [ClaudeProcess]) -> ClaudeProcess? {
        processes.first { process in
            if let profile {
                let clonePath = repository.paths.appExecutableURL(for: profile).path
                let dataPath = repository.paths.userDataURL(for: profile).path
                return Self.normalized(process.executablePath) == Self.normalized(clonePath)
                    || Self.normalized(process.userDataPath) == Self.normalized(dataPath)
            }
            var knownStandardPaths: Set<String> = [
                "/Applications/Claude.app/Contents/MacOS/Claude",
                FileManager.default.homeDirectoryForCurrentUser
                    .appending(path: "Applications/Claude.app/Contents/MacOS/Claude").path,
            ]
            if let cachedPath = cachedInstallation?.executableURL.path {
                knownStandardPaths.insert(cachedPath)
            }
            let normalizedPaths = Set(knownStandardPaths.compactMap(Self.normalized))
            guard let executablePath = Self.normalized(process.executablePath),
                  normalizedPaths.contains(executablePath) else {
                return false
            }
            guard let dataPath = process.userDataPath else { return true }
            return Self.normalized(dataPath)
                == Self.normalized(repository.paths.standardUserDataURL.path)
        }
    }

    func isLegacy(_ process: ClaudeProcess, for profile: ClaudeProfile) -> Bool {
        Self.normalized(process.executablePath)
            != Self.normalized(repository.paths.appExecutableURL(for: profile).path)
            || Self.normalized(process.userDataPath)
            != Self.normalized(repository.paths.userDataURL(for: profile).path)
            || !process.isolatesClaudeCode
    }

    func open(_ profile: ClaudeProfile?, among profiles: [ClaudeProfile]) async throws {
        let lockURL = profile.map(repository.paths.launchLockURL)
            ?? repository.paths.standardLaunchLockURL
        let launchLock = try ProfileLaunchLock(at: lockURL)
        defer { launchLock.unlock() }
        if try await activateIfRunning(profile, among: profiles) { return }
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
            configuration.arguments = [
                "--user-data-dir=\(dataPath)",
                ClaudeProcessScanner.isolationArgument,
            ]
            configuration.environment = managedEnvironment(for: profile)
            let identity = try await updaterPolicy.apply(to: profile, source: verifiedSource)
            target = try await cloneManager.prepare(
                profile: profile,
                from: verifiedSource,
                expectedIdentity: identity
            )
        } else {
            target = verifiedSource
        }
        if try await activateIfRunning(profile, among: profiles, appearedDuringLaunch: true) {
            return
        }
        if let profile {
            try legacyStateQuarantine.runOnce(for: profile)
        }

        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Void, Error>) in
            NSWorkspace.shared.openApplication(
                at: target.appURL,
                configuration: configuration
            ) { application, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if Self.normalized(application?.executableURL?.path)
                    != Self.normalized(target.executableURL.path) {
                    continuation.resume(throwing: ClaudeLauncherError.substitutedApplication)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private func activateIfRunning(
        _ profile: ClaudeProfile?,
        among profiles: [ClaudeProfile],
        appearedDuringLaunch: Bool = false
    ) async throws -> Bool {
        guard let running = process(for: profile, in: try runningProcesses(for: profiles)) else {
            return false
        }
        if let profile {
            if appearedDuringLaunch {
                try await updaterPolicy.markRestartRequired(profile)
                throw ClaudeLauncherError.legacyInstanceRunning
            }
            guard !isLegacy(running, for: profile) else {
                throw ClaudeLauncherError.legacyInstanceRunning
            }
            let clone = ClaudeBundleMetadata.installation(
                at: repository.paths.appURL(for: profile)
            )
            try await updaterPolicy.validateRunning(profile, clone: clone)
        }
        guard let application = NSRunningApplication(processIdentifier: running.pid),
              application.activate(options: [.activateAllWindows]) else {
            throw ClaudeLauncherError.couldNotActivate
        }
        return true
    }

    func reveal(_ profile: ClaudeProfile?) {
        let url = profile.map(repository.paths.containerURL)
            ?? repository.paths.standardUserDataURL
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func managedEnvironment(for profile: ClaudeProfile) -> [String: String] {
        [
            "CLAUDE_CONFIG_DIR": repository.paths.claudeConfigURL(for: profile).path,
            "DISABLE_UPDATE_CHECK": "1",
        ]
    }

    nonisolated private static func normalized(_ path: String?) -> String? {
        path.map(CanonicalFilePath.resolve)
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
