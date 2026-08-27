import XCTest
@testable import ClaudeProfilesApp

final class ClaudeUpdaterStateValidatorTests: XCTestCase {
    func testAllowsOnlyCanonicalClaudeInstallTargets() throws {
        let home = URL(fileURLWithPath: "/Users/test")
        XCTAssertTrue(ClaudeUpdaterStateValidator.isSafe(
            try state(target: "file:///Applications/Claude.app/"),
            homeURL: home
        ))
        XCTAssertTrue(ClaudeUpdaterStateValidator.isSafe(
            try state(target: "file:///Users/test/Applications/Claude.app/"),
            homeURL: home
        ))
        XCTAssertFalse(ClaudeUpdaterStateValidator.isSafe(
            try state(target: "file:///Users/test/Library/Application%20Support/"
                + "Claude%20Profiles/Profiles/ID/Claude.app/"),
            homeURL: home
        ))
        XCTAssertFalse(ClaudeUpdaterStateValidator.isSafe(
            try state(target: "https://example.com/Applications/Claude.app"),
            homeURL: home
        ))
        XCTAssertFalse(ClaudeUpdaterStateValidator.isSafe(Data("broken".utf8), homeURL: home))
    }

    private func state(target: String) throws -> Data {
        try PropertyListSerialization.data(
            fromPropertyList: ["targetBundleURL": target],
            format: .binary,
            options: 0
        )
    }
}
