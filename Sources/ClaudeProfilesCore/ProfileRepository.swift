import Foundation

public final class ProfileRepository {
    public typealias TrashHandler = (URL) throws -> Void

    public let paths: ProfilePaths
    private let fileManager: FileManager
    private let trash: TrashHandler

    public init(
        paths: ProfilePaths = ProfilePaths(),
        fileManager: FileManager = .default,
        trash: @escaping TrashHandler = ProfileRepository.moveToTrash
    ) {
        self.paths = paths
        self.fileManager = fileManager
        self.trash = trash
    }

    public func load() throws -> [ClaudeProfile] {
        guard fileManager.fileExists(atPath: paths.registryURL.path) else { return [] }
        let data = try Data(contentsOf: paths.registryURL)
        return try decoder.decode([ClaudeProfile].self, from: data)
    }

    public func create(named rawName: String, in profiles: [ClaudeProfile]) throws -> [ClaudeProfile] {
        let name = try ProfileName.clean(rawName, existing: profiles)
        let profile = ClaudeProfile(name: name)
        try secureDirectory(at: paths.userDataURL(for: profile))
        try secureDirectory(at: paths.claudeCodeURL(for: profile))
        let updated = profiles + [profile]
        try save(updated)
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
        try secureDirectory(at: paths.userDataURL(for: profile))
        try secureDirectory(at: paths.claudeCodeURL(for: profile))
    }

    private func save(_ profiles: [ClaudeProfile]) throws {
        try secureDirectory(at: paths.rootURL)
        let data = try encoder.encode(profiles)
        try data.write(to: paths.registryURL, options: .atomic)
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
        value.dateEncodingStrategy = .iso8601
        value.outputFormatting = [.prettyPrinted, .sortedKeys]
        return value
    }

    private var decoder: JSONDecoder {
        let value = JSONDecoder()
        value.dateDecodingStrategy = .iso8601
        return value
    }

    private static func moveToTrash(_ url: URL) throws {
        var result: NSURL?
        try FileManager.default.trashItem(at: url, resultingItemURL: &result)
    }
}
