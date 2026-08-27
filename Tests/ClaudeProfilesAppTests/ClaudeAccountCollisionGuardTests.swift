import XCTest
@testable import ClaudeProfilesApp

final class ClaudeAccountCollisionGuardTests: XCTestCase {
    func testFindsMatchingAccountInDifferentRunningLocation() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let account = "08C4DF60-0147-4B12-9B7F-F45FF338C73B"
        try fixture.writeConfig(account: account, to: fixture.targetURL)
        try fixture.writeConfig(account: account.lowercased(), to: fixture.canonicalURL)

        let conflict = ClaudeAccountCollisionGuard().conflict(
            opening: fixture.target,
            whileActive: [fixture.canonical]
        )

        XCTAssertEqual(conflict, fixture.canonical)
    }

    func testFindsMatchingManagedAccountWhenOpeningCanonicalLocation() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let account = "08C4DF60-0147-4B12-9B7F-F45FF338C73B"
        try fixture.writeConfig(account: account, to: fixture.targetURL)
        try fixture.writeConfig(account: account, to: fixture.canonicalURL)

        let conflict = ClaudeAccountCollisionGuard().conflict(
            opening: fixture.canonical,
            whileActive: [fixture.target]
        )

        XCTAssertEqual(conflict, fixture.target)
    }

    func testAllowsDifferentAccounts() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        try fixture.writeConfig(
            account: "B303EA94-0B63-4BB8-8926-3E47D23D97C9",
            to: fixture.targetURL
        )
        try fixture.writeConfig(
            account: "D027A12F-C5C0-4826-946F-1963835E9186",
            to: fixture.canonicalURL
        )

        XCTAssertNil(ClaudeAccountCollisionGuard().conflict(
            opening: fixture.target,
            whileActive: [fixture.canonical]
        ))
    }

    func testMissingOrInvalidAccountDataDoesNotCreateAccountCollision() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        try fixture.writeConfig(
            account: "D027A12F-C5C0-4826-946F-1963835E9186",
            to: fixture.canonicalURL
        )

        XCTAssertNil(ClaudeAccountCollisionGuard().conflict(
            opening: fixture.target,
            whileActive: [fixture.canonical]
        ))

        try fixture.writeConfig(account: "not-a-uuid", to: fixture.targetURL)

        XCTAssertNil(ClaudeAccountCollisionGuard().conflict(
            opening: fixture.target,
            whileActive: [fixture.canonical]
        ))

        try fixture.writeConfig(
            account: "D027A12F-C5C0-4826-946F-1963835E9186",
            to: fixture.targetURL
        )
        try Data("{}".utf8).write(to: fixture.canonicalURL.appending(path: "config.json"))

        XCTAssertNil(ClaudeAccountCollisionGuard().conflict(
            opening: fixture.target,
            whileActive: [fixture.canonical]
        ))
    }

    func testIgnoresSameProfileLocation() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        try fixture.writeConfig(
            account: "D027A12F-C5C0-4826-946F-1963835E9186",
            to: fixture.targetURL
        )

        XCTAssertNil(ClaudeAccountCollisionGuard().conflict(
            opening: fixture.target,
            whileActive: [fixture.target]
        ))
    }
}
