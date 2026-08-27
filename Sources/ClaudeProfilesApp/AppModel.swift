import ClaudeProfilesCore
import Foundation

private enum AccountOpeningBlock {
    case exclusiveSignIn(String)
    case matchingAccount(String)
}

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var profiles: [ClaudeProfile] = []
    @Published private(set) var runningProfileIDs: Set<UUID> = []
    @Published private(set) var legacyProfileIDs: Set<UUID> = []
    @Published private(set) var standardIsRunning = false
    @Published private(set) var launchingKeys: Set<String> = []
    @Published private(set) var registryAvailable = true
    @Published var notice: AppNotice?

    private let repository: ProfileRepository
    private let launcher: ClaudeLauncher
    private let accountCollisionGuard = ClaudeAccountCollisionGuard()

    init(repository: ProfileRepository = ProfileRepository()) {
        self.repository = repository
        self.launcher = ClaudeLauncher(repository: repository)
        do {
            profiles = try repository.load()
        } catch {
            registryAvailable = false
            notice = .error(error)
        }
        refreshStatus()
    }

    func addAndOpen(named name: String) async -> Bool {
        let reservationKey = "new-profile"
        guard launchingKeys.isEmpty else {
            notice = .launchInProgress
            return false
        }
        launchingKeys.insert(reservationKey)
        defer { launchingKeys.remove(reservationKey) }
        do {
            guard try launcher.runningProcesses(for: profiles).isEmpty else {
                notice = .exclusiveSignInRequired()
                return false
            }
            try await launcher.preflight()
            guard try launcher.runningProcesses(for: profiles).isEmpty else {
                notice = .exclusiveSignInRequired()
                return false
            }
            let updated = try repository.create(named: name, in: profiles)
            let profile = updated[updated.endIndex - 1]
            profiles = updated
            launchingKeys.remove(reservationKey)
            if await open(profile) {
                notice = .setup(name: profile.name)
            }
            // The profile exists; close the sheet so a failed launch can be retried from its row.
            return true
        } catch {
            notice = .error(error)
            return false
        }
    }

    @discardableResult
    func open(_ profile: ClaudeProfile?) async -> Bool {
        let key = launchKey(for: profile)
        guard launchingKeys.isEmpty else {
            notice = .launchInProgress
            return false
        }
        launchingKeys.insert(key)
        defer { launchingKeys.remove(key) }
        do {
            if let block = try accountOpeningBlock(for: profile) {
                switch block {
                case let .exclusiveSignIn(ownerName):
                    notice = .exclusiveSignInRequired(profileName: ownerName)
                case let .matchingAccount(activeName):
                    notice = .accountAlreadyRunning(
                        profileName: profile?.name ?? "Existing Claude",
                        runningName: activeName
                    )
                }
                refreshStatus()
                return false
            }
            try await launcher.open(profile, among: profiles)
            refreshStatus()
            let quarantine = LegacyStateQuarantine(paths: repository.paths)
            if let profile, quarantine.hasPendingNotice(for: profile) {
                notice = .legacyIndexesBackedUp(profileName: profile.name)
                try? quarantine.markNoticeShown(for: profile)
            }
            return true
        } catch {
            notice = .error(error)
            return false
        }
    }

    func delete(_ profile: ClaudeProfile) {
        do {
            let launchLock = try ProfileLaunchLock(
                at: repository.paths.launchLockURL(for: profile)
            )
            defer { launchLock.unlock() }
            guard !isLaunching(profile) else { throw ProfileError.profileIsOpening }
            let processes = try launcher.runningProcesses(for: profiles)
            guard launcher.process(for: profile, in: processes) == nil else {
                throw ProfileError.profileIsRunning
            }
            profiles = try repository.delete(profile, from: profiles)
            refreshStatus()
        } catch {
            notice = .error(error)
        }
    }

    func rename(_ profile: ClaudeProfile, to name: String) -> String? {
        guard !isLaunching(profile) else {
            return AppNotice.launchInProgress.message
        }
        do {
            profiles = try repository.rename(profile, to: name, in: profiles)
            return nil
        } catch {
            return AppNotice.error(error).message
        }
    }

    func reveal(_ profile: ClaudeProfile?) {
        launcher.reveal(profile)
    }

    func refreshStatus() {
        guard let processes = try? launcher.runningProcesses(for: profiles) else {
            runningProfileIDs = []
            legacyProfileIDs = []
            standardIsRunning = false
            return
        }
        let matched = profiles.compactMap { profile -> (ClaudeProfile, ClaudeProcess)? in
            launcher.process(for: profile, in: processes).map { (profile, $0) }
        }
        runningProfileIDs = Set(matched.map { $0.0.id })
        legacyProfileIDs = Set(matched.compactMap { profile, process in
            launcher.isLegacy(process, for: profile) ? profile.id : nil
        })
        standardIsRunning = launcher.process(for: nil, in: processes) != nil
    }

    func isRunning(_ profile: ClaudeProfile?) -> Bool {
        profile.map { runningProfileIDs.contains($0.id) } ?? standardIsRunning
    }

    func isLaunching(_ profile: ClaudeProfile?) -> Bool {
        launchingKeys.contains(launchKey(for: profile))
    }

    func needsRestart(_ profile: ClaudeProfile?) -> Bool {
        profile.map { legacyProfileIDs.contains($0.id) } ?? false
    }

    private func launchKey(for profile: ClaudeProfile?) -> String {
        profile?.id.uuidString ?? "standard"
    }

    private func accountOpeningBlock(for profile: ClaudeProfile?) throws -> AccountOpeningBlock? {
        let processes = try launcher.runningProcesses(for: profiles)
        guard launcher.process(for: profile, in: processes) == nil else { return nil }

        var activeLocations: [ClaudeAccountLocation] = []
        if launcher.process(for: nil, in: processes) != nil || isLaunching(nil) {
            activeLocations.append(accountLocation(for: nil))
        }
        activeLocations += profiles.compactMap { candidate in
            guard launcher.process(for: candidate, in: processes) != nil
                    || isLaunching(candidate) else { return nil }
            return accountLocation(for: candidate)
        }
        let target = accountLocation(for: profile)
        if let owner = accountCollisionGuard.exclusiveSetupOwner(
            opening: target,
            whileActive: activeLocations
        ) {
            return .exclusiveSignIn(owner.displayName)
        }
        return accountCollisionGuard.conflict(
            opening: target,
            whileActive: activeLocations
        ).map { .matchingAccount($0.displayName) }
    }

    private func accountLocation(for profile: ClaudeProfile?) -> ClaudeAccountLocation {
        ClaudeAccountLocation(
            profileID: profile?.id,
            displayName: profile?.name ?? "Existing Claude",
            userDataURL: profile.map(repository.paths.userDataURL)
                ?? repository.paths.standardUserDataURL
        )
    }
}
