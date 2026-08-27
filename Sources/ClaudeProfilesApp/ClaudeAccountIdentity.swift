import Foundation

struct ClaudeAccountIdentity: Equatable, Sendable {
    private let value: UUID

    init?(rawValue: String) {
        guard let value = UUID(uuidString: rawValue) else { return nil }
        self.value = value
    }
}

struct ClaudeAccountLocation: Equatable, Sendable {
    let profileID: UUID?
    let displayName: String
    let userDataURL: URL
}

struct ClaudeAccountIdentityReader: Sendable {
    func identity(in userDataURL: URL) -> ClaudeAccountIdentity? {
        let configURL = userDataURL.appending(path: "config.json")
        guard let data = try? Data(contentsOf: configURL),
              let config = try? JSONDecoder().decode(Config.self, from: data),
              let value = config.lastKnownAccountUuid else {
            return nil
        }
        return ClaudeAccountIdentity(rawValue: value)
    }

    private struct Config: Decodable {
        let lastKnownAccountUuid: String?
    }
}

struct ClaudeAccountCollisionGuard: Sendable {
    private let reader = ClaudeAccountIdentityReader()

    func exclusiveSetupOwner(
        opening target: ClaudeAccountLocation,
        whileActive locations: [ClaudeAccountLocation]
    ) -> ClaudeAccountLocation? {
        let others = locations.filter { $0.profileID != target.profileID }
        if !others.isEmpty, reader.identity(in: target.userDataURL) == nil {
            return target
        }
        return others.first { reader.identity(in: $0.userDataURL) == nil }
    }

    func conflict(
        opening target: ClaudeAccountLocation,
        whileActive locations: [ClaudeAccountLocation]
    ) -> ClaudeAccountLocation? {
        guard let targetIdentity = reader.identity(in: target.userDataURL) else { return nil }
        return locations.first { location in
            location.profileID != target.profileID
                && reader.identity(in: location.userDataURL) == targetIdentity
        }
    }
}
