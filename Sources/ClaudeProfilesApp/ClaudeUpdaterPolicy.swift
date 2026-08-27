import ClaudeProfilesCore
import CoreFoundation
import Foundation

actor ClaudeUpdaterPolicy {
    private let paths: ProfilePaths
    private let fileManager: FileManager
    private var compatibleIdentity: Data?
    private static let validatedIdentities: Set<Data> = [
        Data([0x03, 0x81, 0x78, 0x15, 0xe9, 0x09, 0xaa, 0x37, 0x8f, 0xce,
              0x12, 0x8a, 0x6a, 0x5a, 0x43, 0xac, 0x06, 0xb6, 0xb7, 0x8f]),
        Data([0xa3, 0x48, 0xf1, 0x74, 0x6b, 0xb9, 0xb5, 0x28, 0x14, 0x89,
              0xe2, 0x37, 0x3a, 0x08, 0x25, 0xe3, 0xfe, 0x80, 0xc8, 0x60]),
    ]

    init(paths: ProfilePaths, fileManager: FileManager = .default) {
        self.paths = paths
        self.fileManager = fileManager
    }

    func apply(to profile: ClaudeProfile, source: ClaudeInstallation) throws -> Data {
        let identity = try requireCompatibility(with: source)
        try requireCompatibleManagedPolicy()
        try requireSafeUpdaterTarget()
        let store = ClaudePolicyStore(paths: paths, fileManager: fileManager)
        try store.establish(for: profile, identity: identity)
        try store.clearRestartRequirement(for: profile)
        return identity
    }

    func validateRunning(_ profile: ClaudeProfile, clone: ClaudeInstallation) throws {
        let identity = try requireCompatibility(with: clone)
        try requireCompatibleManagedPolicy()
        try requireSafeUpdaterTarget()
        let store = ClaudePolicyStore(paths: paths, fileManager: fileManager)
        guard !store.requiresRestart(for: profile) else {
            throw ClaudeUpdaterPolicyError.restartRequired
        }
        guard try !store.isEstablished(for: profile, identity: identity) else { return }
        try store.markRestartRequired(for: profile)
        throw ClaudeUpdaterPolicyError.restartRequired
    }

    func markRestartRequired(_ profile: ClaudeProfile) throws {
        try ClaudePolicyStore(paths: paths, fileManager: fileManager)
            .markRestartRequired(for: profile)
    }

    private func requireCompatibility(with source: ClaudeInstallation) throws -> Data {
        let identity = try ClaudeSignatureVerifier().identity(of: source.appURL)
        guard compatibleIdentity != identity else { return identity }
        guard Self.validatedIdentities.contains(identity) else {
            throw ClaudeUpdaterPolicyError.incompatibleVersion
        }
        let asarURL = source.appURL.appending(path: "Contents/Resources/app.asar")
        let data = try Data(contentsOf: asarURL, options: .mappedIfSafe)
        let markers = ["disableAutoUpdates", "Auto-updates disabled by enterprise policy",
                       "configLibrary", "_meta.json", "appliedId"]
        guard markers.allSatisfy({ data.range(of: Data($0.utf8)) != nil }) else {
            throw ClaudeUpdaterPolicyError.incompatibleVersion
        }
        compatibleIdentity = identity
        return identity
    }

    private func requireCompatibleManagedPolicy() throws {
        let base = URL(fileURLWithPath: "/Library/Managed Preferences", isDirectory: true)
        let urls = [base.appending(path: "com.anthropic.claudefordesktop.plist"),
                    base.appending(path: "\(NSUserName())/com.anthropic.claudefordesktop.plist")]
        for url in urls where fileManager.fileExists(atPath: url.path) {
            let data = try Data(contentsOf: url)
            guard let values = try PropertyListSerialization.propertyList(from: data, format: nil)
                    as? [String: Any], values.isEmpty
                    || Self.isTrue(values["disableAutoUpdates"]) else {
                throw ClaudeUpdaterPolicyError.managedPolicyConflict
            }
        }
    }

    private func requireSafeUpdaterTarget() throws {
        let stateURL = fileManager.homeDirectoryForCurrentUser.appending(
            path: "Library/Caches/com.anthropic.claudefordesktop.ShipIt/ShipItState.plist"
        )
        guard fileManager.fileExists(atPath: stateURL.path) else { return }
        guard let data = try? Data(contentsOf: stateURL),
              ClaudeUpdaterStateValidator.isSafe(
                data,
                homeURL: fileManager.homeDirectoryForCurrentUser,
                managedRootURL: paths.rootURL
              ) else {
            throw ClaudeUpdaterPolicyError.unsafeUpdaterState
        }
    }

    nonisolated private static func isTrue(_ value: Any?) -> Bool {
        guard let value, CFGetTypeID(value as CFTypeRef) == CFBooleanGetTypeID() else {
            return false
        }
        return (value as? Bool) == true
    }

}
