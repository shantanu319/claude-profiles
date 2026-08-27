import ClaudeProfilesCore
import CoreFoundation
import Foundation

struct ClaudePolicyStore {
    private let paths: ProfilePaths
    private let fileManager: FileManager

    init(paths: ProfilePaths, fileManager: FileManager) {
        self.paths = paths
        self.fileManager = fileManager
    }

    func disableAutoUpdates(for profile: ClaudeProfile) throws {
        let policyDataURL = URL(
            fileURLWithPath: paths.userDataURL(for: profile).path + "-3p",
            isDirectory: true
        )
        let libraryURL = policyDataURL.appending(path: "configLibrary", directoryHint: .isDirectory)
        try secureDirectory(policyDataURL)
        try secureDirectory(libraryURL)

        let metaURL = libraryURL.appending(path: "_meta.json")
        var meta = try dictionary(at: metaURL) ?? [:]
        let identifier = try activeIdentifier(in: &meta)
        var entries = try policyEntries(in: meta)
        if !entries.contains(where: { $0["id"] as? String == identifier }) {
            entries.append(["id": identifier, "name": "Default"])
            meta["entries"] = entries
        }

        let configURL = libraryURL.appending(path: "\(identifier).json")
        var config = try dictionary(at: configURL) ?? [:]
        config["disableAutoUpdates"] = true
        try write(config, to: configURL)
        try write(meta, to: metaURL)
    }

    func establish(for profile: ClaudeProfile, identity: Data) throws {
        try disableAutoUpdates(for: profile)
        try writePrivate(identity, to: receiptURL(for: profile))
    }

    func isEstablished(for profile: ClaudeProfile, identity: Data) throws -> Bool {
        guard (try? Data(contentsOf: receiptURL(for: profile))) == identity,
              let meta = try dictionary(at: policyLibraryURL(for: profile)
                .appending(path: "_meta.json")),
              let identifier = meta["appliedId"] as? String,
              identifier == identifier.lowercased(),
              UUID(uuidString: identifier) != nil,
              let config = try dictionary(at: policyLibraryURL(for: profile)
                .appending(path: "\(identifier).json")),
              let value = config["disableAutoUpdates"],
              CFGetTypeID(value as CFTypeRef) == CFBooleanGetTypeID() else {
            return false
        }
        return (value as? Bool) == true
    }

    func requiresRestart(for profile: ClaudeProfile) -> Bool {
        fileManager.fileExists(atPath: restartURL(for: profile).path)
    }

    func markRestartRequired(for profile: ClaudeProfile) throws {
        try writePrivate(Data(), to: restartURL(for: profile))
    }

    func clearRestartRequirement(for profile: ClaudeProfile) throws {
        let url = restartURL(for: profile)
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }

    private func activeIdentifier(in meta: inout [String: Any]) throws -> String {
        if let existing = meta["appliedId"] {
            guard let value = existing as? String,
                  value == value.lowercased(), UUID(uuidString: value) != nil else {
                throw ClaudeUpdaterPolicyError.invalidConfiguration
            }
            return value
        }
        let value = UUID().uuidString.lowercased()
        meta["appliedId"] = value
        return value
    }

    private func policyEntries(in meta: [String: Any]) throws -> [[String: Any]] {
        guard let value = meta["entries"] else { return [] }
        guard let entries = value as? [[String: Any]] else {
            throw ClaudeUpdaterPolicyError.invalidConfiguration
        }
        return entries
    }

    private func dictionary(at url: URL) throws -> [String: Any]? {
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        let value = try JSONSerialization.jsonObject(with: Data(contentsOf: url))
        guard let dictionary = value as? [String: Any] else {
            throw ClaudeUpdaterPolicyError.invalidConfiguration
        }
        return dictionary
    }

    private func write(_ value: [String: Any], to url: URL) throws {
        let data = try JSONSerialization.data(
            withJSONObject: value,
            options: [.prettyPrinted, .sortedKeys]
        )
        try data.write(to: url, options: .atomic)
        try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    private func writePrivate(_ data: Data, to url: URL) throws {
        try data.write(to: url, options: .atomic)
        try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    private func policyLibraryURL(for profile: ClaudeProfile) -> URL {
        URL(fileURLWithPath: paths.userDataURL(for: profile).path + "-3p")
            .appending(path: "configLibrary")
    }

    private func receiptURL(for profile: ClaudeProfile) -> URL {
        paths.containerURL(for: profile).appending(path: ".updater-policy-v1")
    }

    private func restartURL(for profile: ClaudeProfile) -> URL {
        paths.containerURL(for: profile).appending(path: ".updater-restart-required")
    }

    private func secureDirectory(_ url: URL) throws {
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: url.path)
    }
}
