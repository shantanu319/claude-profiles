import Foundation

public final class ProfileRepository {
    public typealias TrashHandler = (URL) throws -> Void

    public let paths: ProfilePaths
    private let fileManager: FileManager
    private let trash: TrashHandler

    public init(
        paths: ProfilePaths = ProfilePaths(),
        fileManager: FileManager = .default,
        trash: @escaping TrashHandler = { url in
            var result: NSURL?
            try FileManager.default.trashItem(at: url, resultingItemURL: &result)
        }
    ) {
        self.paths = paths
        self.fileManager = fileManager
        self.trash = trash
    }

    public func load() throws -> [ClaudeProfile] {
        let (registry, cacheWritable) = loadRegistry()
        var registryByID: [UUID: ClaudeProfile] = [:]
        for profile in registry {
            registryByID[profile.id] = validated(profile, matching: profile.id)
        }
        guard fileManager.fileExists(atPath: paths.profilesURL.path) else {
            if cacheWritable { try? save([]) }
            return []
        }

        let keys: Set<URLResourceKey> = [.isDirectoryKey, .isSymbolicLinkKey, .creationDateKey]
        let containers = try fileManager.contentsOfDirectory(
            at: paths.profilesURL,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        )
        var profiles: [ClaudeProfile] = []
        for container in containers {
            guard let identifier = UUID(uuidString: container.lastPathComponent),
                  container.lastPathComponent == identifier.uuidString else { continue }
            let values = try container.resourceValues(forKeys: keys)
            guard values.isDirectory == true, values.isSymbolicLink != true else { continue }
            let metadataURL = container.appending(path: "profile.json")
            let metadata = decodedMetadata(at: metadataURL)
                .flatMap { validated($0, matching: identifier) }
            let profile = metadata
                ?? registryByID[identifier]
                ?? ClaudeProfile(
                    id: identifier,
                    name: "Recovered \(identifier.uuidString)",
                    createdAt: values.creationDate ?? Date(timeIntervalSince1970: 0)
                )
            profiles.append(profile)
            if !fileManager.fileExists(atPath: metadataURL.path) {
                try? saveMetadata(profile)
            }
        }
        profiles.sort {
            ($0.createdAt, $0.id.uuidString) < ($1.createdAt, $1.id.uuidString)
        }
        if cacheWritable { try? save(profiles) }
        return profiles
    }

    public func create(named rawName: String, in profiles: [ClaudeProfile]) throws -> [ClaudeProfile] {
        let name = try ProfileName.clean(rawName, existing: profiles)
        let profile = ClaudeProfile(name: name)
        try secureDirectories(for: profile)
        try saveMetadata(profile)
        let updated = profiles + [profile]
        do {
            try save(updated)
        } catch {
            try? fileManager.removeItem(at: paths.containerURL(for: profile))
            throw error
        }
        return updated
    }

    public func delete(_ profile: ClaudeProfile, from profiles: [ClaudeProfile]) throws -> [ClaudeProfile] {
        let updated = profiles.filter { $0.id != profile.id }
        try save(updated)
        let container = paths.containerURL(for: profile)
        guard fileManager.fileExists(atPath: container.path) else { return updated }
        do {
            try trash(container)
            return updated
        } catch {
            try? save(profiles)
            throw error
        }
    }

    public func ensureDirectories(for profile: ClaudeProfile) throws {
        try secureDirectories(for: profile)
        if !fileManager.fileExists(atPath: paths.metadataURL(for: profile).path) {
            try saveMetadata(profile)
        }
    }

    private func save(_ profiles: [ClaudeProfile]) throws {
        try secureDirectory(at: paths.rootURL)
        let data = try encoder.encode(profiles)
        try data.write(to: paths.registryURL, options: .atomic)
        try fileManager.setAttributes([.posixPermissions: 0o600],
                                      ofItemAtPath: paths.registryURL.path)
    }

    private func loadRegistry() -> ([ClaudeProfile], Bool) {
        guard fileManager.fileExists(atPath: paths.registryURL.path) else { return ([], true) }
        guard let data = try? Data(contentsOf: paths.registryURL),
              let profiles = try? decoder.decode([ClaudeProfile].self, from: data) else {
            return ([], false)
        }
        return (profiles, true)
    }

    private func decodedMetadata(at url: URL) -> ClaudeProfile? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(ClaudeProfile.self, from: data)
    }

    private func validated(_ profile: ClaudeProfile, matching id: UUID) -> ClaudeProfile? {
        guard profile.id == id,
              (try? ProfileName.clean(profile.name, existing: [])) == profile.name else {
            return nil
        }
        return profile
    }

    private func saveMetadata(_ profile: ClaudeProfile) throws {
        let url = paths.metadataURL(for: profile)
        try encoder.encode(profile).write(to: url, options: .atomic)
        try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    private func secureDirectories(for profile: ClaudeProfile) throws {
        try secureDirectory(at: paths.rootURL)
        try secureDirectory(at: paths.profilesURL)
        try secureDirectory(at: paths.containerURL(for: profile))
        try secureDirectory(at: paths.userDataURL(for: profile))
    }

    private func secureDirectory(at url: URL) throws {
        try fileManager.createDirectory(
            at: url,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: url.path)
    }

    private var encoder: JSONEncoder {
        let value = JSONEncoder()
        value.dateEncodingStrategy = .secondsSince1970
        value.outputFormatting = [.prettyPrinted, .sortedKeys]
        return value
    }

    private var decoder: JSONDecoder {
        let value = JSONDecoder()
        value.dateDecodingStrategy = .secondsSince1970
        return value
    }
}
