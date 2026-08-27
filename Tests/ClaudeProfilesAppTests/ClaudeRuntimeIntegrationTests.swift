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
            try? FileManager.default.removeItem(at: root)
        }

        let launcher = ClaudeLauncher(locator: locator, repository: repository)
        try await launcher.open(profile, among: [profile])
        let process = try await waitForProcess(at: paths.appExecutableURL(for: profile).path)
        cloneApplication = try XCTUnwrap(NSRunningApplication(processIdentifier: process.pid))
        XCTAssertEqual(
            cloneApplication?.executableURL?.standardizedFileURL,
            paths.appExecutableURL(for: profile).standardizedFileURL
        )
        XCTAssertEqual(
            URL(fileURLWithPath: try XCTUnwrap(process.userDataPath)).standardizedFileURL,
            paths.userDataURL(for: profile).standardizedFileURL
        )

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
        let tamperURL = paths.appURL(for: profile).appending(path: "Contents/Resources/tamper")
        try Data("tamper".utf8).write(to: tamperURL)
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
}
