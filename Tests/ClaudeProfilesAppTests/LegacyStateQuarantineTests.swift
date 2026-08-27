import ClaudeProfilesCore
import XCTest
@testable import ClaudeProfilesApp

final class LegacyStateQuarantineTests: XCTestCase {
    func testMovesMixedDesktopIndexesAsideWithoutTouchingGlobalTranscripts() throws {
        let root = FileManager.default.temporaryDirectory.appending(
            path: "LegacyStateQuarantineTests-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        defer { try? FileManager.default.removeItem(at: root) }
        let paths = ProfilePaths(rootURL: root.appending(path: "Profiles"), applicationSupportURL: root)
        let repository = ProfileRepository(paths: paths)
        let profile = try XCTUnwrap(repository.create(named: "Work", in: []).first)
        let userData = paths.userDataURL(for: profile)
        let globalTranscript = root.appending(path: ".claude/projects/work/session.jsonl")
        try write("desktop", to: userData.appending(path: "claude-code-sessions/item.json"))
        try write("agent", to: userData.appending(path: "local-agent-mode-sessions/item.json"))
        try write("global", to: globalTranscript)

        let quarantine = LegacyStateQuarantine(paths: paths)
        XCTAssertTrue(quarantine.needsRun(for: profile))
        try quarantine.runOnce(for: profile)

        let backup = paths.containerURL(for: profile)
            .appending(path: "Legacy Shared Session Indexes")
        XCTAssertEqual(try text(at: backup.appending(path: "claude-code-sessions/item.json")), "desktop")
        XCTAssertEqual(try text(at: backup.appending(path: "local-agent-mode-sessions/item.json")), "agent")
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: userData.appending(path: "claude-code-sessions").path
        ))
        XCTAssertEqual(try text(at: globalTranscript), "global")
        XCTAssertFalse(quarantine.needsRun(for: profile))
        XCTAssertTrue(quarantine.hasPendingNotice(for: profile))
        XCTAssertTrue(try text(at: backup.appending(path: "README.txt")).contains("not moved"))

        try quarantine.runOnce(for: profile)
        XCTAssertTrue(FileManager.default.fileExists(atPath: backup.path))
        try quarantine.markNoticeShown(for: profile)
        XCTAssertFalse(quarantine.hasPendingNotice(for: profile))
    }

    func testPreservesPreexistingBackupDuringRetry() throws {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let paths = ProfilePaths(rootURL: root, applicationSupportURL: root)
        let repository = ProfileRepository(paths: paths)
        let profile = try XCTUnwrap(repository.create(named: "Work", in: []).first)
        let quarantine = LegacyStateQuarantine(paths: paths)
        let backup = quarantine.backupURL(for: profile)
        try write("first", to: backup.appending(path: "claude-code-sessions/item"))
        try write("retry", to: paths.userDataURL(for: profile)
            .appending(path: "claude-code-sessions/item"))

        try quarantine.runOnce(for: profile)

        XCTAssertEqual(try text(at: backup.appending(path: "claude-code-sessions/item")), "first")
        XCTAssertEqual(try text(at: backup.appending(path: "claude-code-sessions-2/item")), "retry")
    }

    private func write(_ value: String, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data(value.utf8).write(to: url, options: .atomic)
    }

    private func text(at url: URL) throws -> String {
        String(decoding: try Data(contentsOf: url), as: UTF8.self)
    }
}
