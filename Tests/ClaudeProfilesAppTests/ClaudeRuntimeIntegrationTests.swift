import AppKit
import ClaudeProfilesCore
import XCTest
@testable import ClaudeProfilesApp

final class ClaudeRuntimeIntegrationTests: XCTestCase {
    @MainActor
    func testExactCloneLaunchAndAtomicRefresh() async throws {
        guard ProcessInfo.processInfo.environment["CLAUDE_PROFILES_INTEGRATION_TEST"] == "1" else {
            throw XCTSkip("Set CLAUDE_PROFILES_INTEGRATION_TEST=1 to run the real-app smoke test.")
        }

        let root = FileManager.default.temporaryDirectory.appending(
            path: "ClaudeProfilesIntegration-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        let paths = ProfilePaths(rootURL: root, applicationSupportURL: root)
        let repository = ProfileRepository(paths: paths)
        let profile = try XCTUnwrap(repository.create(named: "Probe", in: []).first)
        let locator = ClaudeInstallationLocator(managedRootURL: root)
        let source = try locator.locate()
        let standardPIDs = try mainPIDs(at: source.executableURL.path)
        var cloneApplication: NSRunningApplication?

        defer {
            cloneApplication?.terminate()
            let clonePath = paths.appExecutableURL(for: profile).path
            try? ClaudeProcessScanner(executablePath: clonePath).snapshot().forEach {
                NSRunningApplication(processIdentifier: $0.pid)?.terminate()
            }
            try? FileManager.default.removeItem(at: root)
        }

        let launcher = ClaudeLauncher(locator: locator, repository: repository)
        try await launcher.open(profile, among: [profile])
        var process = try await waitForProcess(at: paths.appExecutableURL(for: profile).path)
        cloneApplication = try XCTUnwrap(NSRunningApplication(processIdentifier: process.pid))
        XCTAssertEqual(
            try canonicalPath(of: XCTUnwrap(cloneApplication?.executableURL)),
            try canonicalPath(of: paths.appExecutableURL(for: profile))
        )
        XCTAssertEqual(
            try canonicalPath(of: URL(fileURLWithPath: XCTUnwrap(process.userDataPath))),
            try canonicalPath(of: paths.userDataURL(for: profile))
        )

        let receiptURL = paths.containerURL(for: profile).appending(path: ".updater-policy-v1")
        try FileManager.default.removeItem(at: receiptURL)
        do {
            try await launcher.open(profile, among: [profile])
            XCTFail("A running pre-policy clone must require a restart")
        } catch ClaudeUpdaterPolicyError.restartRequired {
        }
        cloneApplication?.terminate()
        try await waitForExit(process.pid)
        cloneApplication = nil
        try await launcher.open(profile, among: [profile])
        process = try await waitForProcess(at: paths.appExecutableURL(for: profile).path)
        cloneApplication = try XCTUnwrap(NSRunningApplication(processIdentifier: process.pid))
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: paths.containerURL(for: profile)
                .appending(path: ".updater-restart-required").path
        ))

        let verifier = ClaudeSignatureVerifier()
        XCTAssertEqual(
            try verifier.identity(of: source.appURL),
            try verifier.identity(of: paths.appURL(for: profile))
        )
        let firstInode = try inode(of: paths.appURL(for: profile))
        cloneApplication?.terminate()
        try await waitForExit(process.pid)
        cloneApplication = nil
        XCTAssertTrue(standardPIDs.isSubset(of: try mainPIDs(at: source.executableURL.path)))

        let manager = ClaudeCloneManager(paths: paths)
        _ = try await manager.prepare(profile: profile, from: source)
        XCTAssertEqual(firstInode, try inode(of: paths.appURL(for: profile)))
        let displacedURL = paths.containerURL(for: profile).appending(path: "Displaced.app")
        try FileManager.default.moveItem(at: paths.appURL(for: profile), to: displacedURL)
        try FileManager.default.createDirectory(
            at: paths.appURL(for: profile),
            withIntermediateDirectories: false
        )
        _ = try await manager.prepare(profile: profile, from: source)
        XCTAssertNotEqual(firstInode, try inode(of: paths.appURL(for: profile)))
        XCTAssertEqual(
            try verifier.identity(of: source.appURL),
            try verifier.identity(of: paths.appURL(for: profile))
        )
        let residue = try FileManager.default.contentsOfDirectory(atPath: paths.containerURL(for: profile).path)
        XCTAssertFalse(residue.contains { $0.hasPrefix(".Claude-creating-") })
    }

    private func mainPIDs(at executable: String) throws -> Set<pid_t> {
        Set(try ClaudeProcessScanner(executablePath: executable).snapshot().map(\.pid))
    }

    private func inode(of url: URL) throws -> NSNumber {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return try XCTUnwrap(attributes[.systemFileNumber] as? NSNumber)
    }

    private func canonicalPath(of url: URL) throws -> String {
        try XCTUnwrap(url.resourceValues(forKeys: [.canonicalPathKey]).canonicalPath)
    }
}
