import XCTest
@testable import ClaudeProfilesApp

final class ClaudeAccountSetupGuardTests: XCTestCase {
    func testUnconfiguredManagedProfileRequiresExclusiveSetup() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }

        XCTAssertEqual(ClaudeAccountCollisionGuard().exclusiveSetupOwner(
            opening: fixture.target,
            whileActive: [fixture.canonical]
        ), fixture.target)
        XCTAssertNil(ClaudeAccountCollisionGuard().exclusiveSetupOwner(
            opening: fixture.target,
            whileActive: []
        ))
    }

    func testConfiguredLocationsDoNotRequireExclusiveSetup() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        try fixture.writeConfig(
            account: "D027A12F-C5C0-4826-946F-1963835E9186",
            to: fixture.targetURL
        )
        try fixture.writeConfig(
            account: "B303EA94-0B63-4BB8-8926-3E47D23D97C9",
            to: fixture.canonicalURL
        )
        XCTAssertNil(ClaudeAccountCollisionGuard().exclusiveSetupOwner(
            opening: fixture.target,
            whileActive: [fixture.canonical]
        ))
    }

    func testUnknownCanonicalTargetRequiresExclusiveSetup() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }

        XCTAssertEqual(ClaudeAccountCollisionGuard().exclusiveSetupOwner(
            opening: fixture.canonical,
            whileActive: [fixture.target]
        ), fixture.canonical)
    }

    func testActiveUnconfiguredProfileBlocksAnyOtherLaunch() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        try fixture.writeConfig(
            account: "D027A12F-C5C0-4826-946F-1963835E9186",
            to: fixture.canonicalURL
        )

        XCTAssertEqual(ClaudeAccountCollisionGuard().exclusiveSetupOwner(
            opening: fixture.canonical,
            whileActive: [fixture.target]
        ), fixture.target)
    }
}
