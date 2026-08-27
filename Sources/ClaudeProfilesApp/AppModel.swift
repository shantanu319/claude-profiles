import ClaudeProfilesCore
import Foundation

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
        do {
            try await launcher.preflight()
            let updated = try repository.create(named: name, in: profiles)
            let profile = updated[updated.endIndex - 1]
            profiles = updated
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
        guard launchingKeys.insert(key).inserted else { return false }
        defer { launchingKeys.remove(key) }
        do {
            try await launcher.open(profile, among: profiles)
            refreshStatus()
            return true
        } catch {
            notice = .error(error)
            return false
        }
    }

    func delete(_ profile: ClaudeProfile) {
        do {
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
}
