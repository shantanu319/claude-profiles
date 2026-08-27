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

    public func launchLockURL(for profile: ClaudeProfile) -> URL {
        rootURL.appending(path: ".launch-\(profile.id.uuidString).lock")
    }

    public var standardLaunchLockURL: URL {
        rootURL.appending(path: ".launch-standard.lock")
    }

    public func containerURL(for profile: ClaudeProfile) -> URL {
        profilesURL.appending(path: profile.id.uuidString, directoryHint: .isDirectory)
    }

    public func userDataURL(for profile: ClaudeProfile) -> URL {
        containerURL(for: profile).appending(path: "User Data", directoryHint: .isDirectory)
    }

    public func claudeConfigURL(for profile: ClaudeProfile) -> URL {
        containerURL(for: profile).appending(path: "Claude Config", directoryHint: .isDirectory)
    }

    public func metadataURL(for profile: ClaudeProfile) -> URL {
        containerURL(for: profile).appending(path: "profile.json")
    }

    public func appURL(for profile: ClaudeProfile) -> URL {
        containerURL(for: profile).appending(path: "Claude.app", directoryHint: .isDirectory)
    }

    public func appExecutableURL(for profile: ClaudeProfile) -> URL {
        appURL(for: profile).appending(path: "Contents/MacOS/Claude")
    }
}
