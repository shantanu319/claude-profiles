import ClaudeProfilesCore
import Darwin
import Foundation

enum ClaudeCloneError: LocalizedError {
    case invalidBundle

    var errorDescription: String? {
        "Could not build a valid Claude app copy for this profile."
    }
}

actor ClaudeCloneManager {
    private static let stagingPrefix = ".Claude-creating-"
    private static let staleStagingAge: TimeInterval = 60 * 60
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
        try cleanupStagingBundles(in: containerURL)

        let sourceIdentity = try signatureVerifier.identity(of: source.appURL)
        let targetURL = paths.appURL(for: profile)
        if isFresh(targetURL, matching: sourceIdentity) {
            return ClaudeBundleMetadata.installation(at: targetURL)
        }

        let temporaryURL = containerURL.appending(
            path: "\(Self.stagingPrefix)\(Int(Date().timeIntervalSince1970))-"
                + "\(UUID().uuidString).app",
            directoryHint: .isDirectory
        )
        do {
            try await clone(source.appURL, to: temporaryURL)
            guard try signatureVerifier.identity(of: temporaryURL) == sourceIdentity else {
                throw ClaudeCloneError.invalidBundle
            }
            try install(temporaryURL, at: targetURL)
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
            let status = newURL.path.withCString { newPath in
                targetURL.path.withCString { targetPath in
                    renameatx_np(
                        AT_FDCWD,
                        newPath,
                        AT_FDCWD,
                        targetPath,
                        UInt32(RENAME_SWAP)
                    )
                }
            }
            guard status == 0 else {
                throw CocoaError(.fileWriteUnknown, userInfo: [
                    NSUnderlyingErrorKey: POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO),
                ])
            }
            try? fileManager.removeItem(at: newURL)
        } else {
            try fileManager.moveItem(at: newURL, to: targetURL)
        }
    }

    private func isFresh(_ targetURL: URL, matching sourceIdentity: Data) -> Bool {
        fileManager.fileExists(atPath: targetURL.path)
            && (try? signatureVerifier.identity(of: targetURL)) == sourceIdentity
    }

    private func cleanupStagingBundles(in containerURL: URL) throws {
        let contents = try fileManager.contentsOfDirectory(
            at: containerURL,
            includingPropertiesForKeys: nil
        )
        for url in contents where
            url.lastPathComponent.hasPrefix(Self.stagingPrefix)
                && url.pathExtension == "app" {
            let suffix = url.deletingPathExtension().lastPathComponent
                .dropFirst(Self.stagingPrefix.count)
            guard let timestamp = suffix.split(separator: "-").first.flatMap(Double.init),
                  Date().timeIntervalSince1970 - timestamp > Self.staleStagingAge else {
                continue
            }
            try fileManager.removeItem(at: url)
        }
    }
}
