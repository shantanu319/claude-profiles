import XCTest
@testable import ClaudeProfilesApp

final class ClaudeUpdaterStateValidatorTests: XCTestCase {
    func testAllowsOnlyCanonicalClaudeInstallTargets() throws {
        let root = FileManager.default.temporaryDirectory.appending(
            path: "UpdaterStateTests-\(UUID().uuidString)"
        )
        defer { try? FileManager.default.removeItem(at: root) }
        let home = root.appending(path: "Home")
        let homeApp = home.appending(path: "Applications/Claude.app")
        let managedRoot = root.appending(path: "Claude Profiles")
        let managedApp = managedRoot.appending(path: "Profiles/ID/Claude.app")
        try FileManager.default.createDirectory(at: homeApp, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: managedApp, withIntermediateDirectories: true)

        XCTAssertTrue(ClaudeUpdaterStateValidator.isSafe(
            try state(target: homeApp.absoluteString),
            homeURL: home,
            managedRootURL: managedRoot
        ))
        XCTAssertFalse(ClaudeUpdaterStateValidator.isSafe(
            try state(target: managedApp.absoluteString),
            homeURL: home,
            managedRootURL: managedRoot
        ))
        XCTAssertFalse(ClaudeUpdaterStateValidator.isSafe(
            try state(target: "https://example.com/Applications/Claude.app"),
            homeURL: home,
            managedRootURL: managedRoot
        ))
        XCTAssertFalse(ClaudeUpdaterStateValidator.isSafe(
            Data("broken".utf8),
            homeURL: home,
            managedRootURL: managedRoot
        ))
    }

    func testRejectsCanonicalPathSymlinkedIntoManagedProfiles() throws {
        let root = FileManager.default.temporaryDirectory.appending(
            path: "UpdaterStateTests-\(UUID().uuidString)"
        )
        defer { try? FileManager.default.removeItem(at: root) }
        let home = root.appending(path: "Home")
        let managedRoot = root.appending(path: "Claude Profiles")
        let managedApp = managedRoot.appending(path: "Profiles/ID/Claude.app")
        let apparentApp = home.appending(path: "Applications/Claude.app")
        try FileManager.default.createDirectory(
            at: managedApp,
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: apparentApp.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try FileManager.default.createSymbolicLink(at: apparentApp, withDestinationURL: managedApp)

        XCTAssertFalse(ClaudeUpdaterStateValidator.isSafe(
            try state(target: apparentApp.absoluteString),
            homeURL: home,
            managedRootURL: managedRoot
        ))
    }

    private func state(target: String) throws -> Data {
        try PropertyListSerialization.data(
            fromPropertyList: ["targetBundleURL": target],
            format: .binary,
            options: 0
        )
    }
}
