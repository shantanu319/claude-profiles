import Foundation

public struct ClaudeProfile: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public let createdAt: Date

    public init(id: UUID = UUID(), name: String, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
    }
}

public enum ProfileError: LocalizedError, Equatable {
    case blankName
    case nameTooLong
    case invalidCharacters
    case duplicateName
    case profileIsRunning
    case profileIsOpening

    public var errorDescription: String? {
        switch self {
        case .blankName:
            "Enter a profile name."
        case .nameTooLong:
            "Keep the profile name to 50 characters or fewer."
        case .invalidCharacters:
            "Profile names cannot contain control characters."
        case .duplicateName:
            "A profile with that name already exists."
        case .profileIsRunning:
            "Quit this Claude app with ⌘Q before deleting it; closing its window is not enough."
        case .profileIsOpening:
            "Wait for this Claude app to finish opening before deleting it."
        }
    }
}

public enum ProfileName {
    public static func clean(_ value: String, existing: [ClaudeProfile]) throws -> String {
        let name = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw ProfileError.blankName }
        guard name.count <= 50 else { throw ProfileError.nameTooLong }
        guard name.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) }) else {
            throw ProfileError.invalidCharacters
        }
        let duplicate = existing.contains { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }
        guard !duplicate else { throw ProfileError.duplicateName }
        return name
    }
}
