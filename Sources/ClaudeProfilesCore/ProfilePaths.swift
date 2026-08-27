import Foundation

public struct ProfilePaths: Sendable {
    public let rootURL: URL
    public let standardUserDataURL: URL

    public init(rootURL: URL? = nil, applicationSupportURL: URL? = nil) {
        let support = applicationSupportURL
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        self.rootURL = rootURL ?? support.appending(path: "Claude Profiles", directoryHint: .isDirectory)
        self.standardUserDataURL = support.appending(path: "Claude", directoryHint: .isDirectory)
    }

    public var registryURL: URL {
        rootURL.appending(path: "profiles.json")
    }

    public var profilesURL: URL {
        rootURL.appending(path: "Profiles", directoryHint: .isDirectory)
    }

    public func containerURL(for profile: ClaudeProfile) -> URL {
        profilesURL.appending(path: profile.id.uuidString, directoryHint: .isDirectory)
    }

    public func userDataURL(for profile: ClaudeProfile) -> URL {
        containerURL(for: profile).appending(path: "User Data", directoryHint: .isDirectory)
    }

    public func claudeCodeURL(for profile: ClaudeProfile) -> URL {
        containerURL(for: profile).appending(path: "Claude Code", directoryHint: .isDirectory)
    }
}
