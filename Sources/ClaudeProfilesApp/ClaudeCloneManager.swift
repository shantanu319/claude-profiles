import ClaudeProfilesCore
import Foundation

enum ClaudeCloneError: LocalizedError {
    case invalidBundle

    var errorDescription: String? {
        "Could not build a valid Claude app copy for this profile."
    }
}

@MainActor
final class ClaudeCloneManager {
    private let paths: ProfilePaths
    private let fileManager: FileManager
    private let signatureVerifier: ClaudeSignatureVerifier

    init(
        paths: ProfilePaths,
        fileManager: FileManager = .default,
        signatureVerifier: ClaudeSignatureVerifier = ClaudeSignatureVerifier()
    ) {
        self.paths = paths
        self.fileManager = fileManager
        self.signatureVerifier = signatureVerifier
    }

    func prepare(
        profile: ClaudeProfile,
        from source: ClaudeInstallation
    ) async throws -> ClaudeInstallation {
        let targetURL = paths.appURL(for: profile)
        if isFresh(targetURL, source: source.appURL) {
            return ClaudeBundleMetadata.installation(at: targetURL)
        }

        let containerURL = paths.containerURL(for: profile)
        try fileManager.createDirectory(
            at: containerURL,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try fileManager.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: containerURL.path
        )

        let temporaryURL = containerURL.appending(
            path: ".Claude-creating-\(UUID().uuidString).app",
            directoryHint: .isDirectory
        )
        do {
            try await clone(source.appURL, to: temporaryURL)
            try signatureVerifier.verify(temporaryURL)
            try install(temporaryURL, at: targetURL)
            try signatureVerifier.verify(targetURL)
            return ClaudeBundleMetadata.installation(at: targetURL)
        } catch {
            if fileManager.fileExists(atPath: temporaryURL.path) {
                try? fileManager.removeItem(at: temporaryURL)
            }
            throw error
        }
    }

    private func clone(_ sourceURL: URL, to destinationURL: URL) async throws {
        try await AsyncCommand.run(
            executable: URL(fileURLWithPath: "/usr/bin/ditto"),
            arguments: [
                "--clone", "--rsrc", "--extattr", "--acl", "--qtn",
                sourceURL.path, destinationURL.path,
            ]
        )
    }

    private func install(_ newURL: URL, at targetURL: URL) throws {
        if fileManager.fileExists(atPath: targetURL.path) {
            _ = try fileManager.replaceItemAt(targetURL, withItemAt: newURL)
        } else {
            try fileManager.moveItem(at: newURL, to: targetURL)
        }
    }

    private func isFresh(_ targetURL: URL, source sourceURL: URL) -> Bool {
        guard fileManager.fileExists(atPath: targetURL.path),
              ClaudeBundleMetadata.version(at: targetURL)
                == ClaudeBundleMetadata.version(at: sourceURL) else {
            return false
        }
        return (try? signatureVerifier.verify(targetURL)) != nil
    }
}
