import XCTest
@testable import ClaudeProfilesApp

final class AppNoticeTests: XCTestCase {
    func testSetupExplainsGlobalOAuthCallbackBeforeSignIn() {
        let notice = AppNotice.setup(name: "Work")

        XCTAssertEqual(notice.title, "Set up Work")
        XCTAssertTrue(notice.message.contains("Before signing in"))
        XCTAssertTrue(notice.message.contains("quit every other Claude app"))
        XCTAssertTrue(notice.message.contains("claude:// OAuth callback"))
    }

    func testCollisionNoticeNamesProfilesWithoutAccountIdentifier() {
        let notice = AppNotice.accountAlreadyRunning(
            profileName: "Work",
            runningName: "Existing Claude"
        )

        XCTAssertEqual(notice.title, "Account already open")
        XCTAssertTrue(notice.message.contains("Work"))
        XCTAssertTrue(notice.message.contains("Existing Claude"))
        XCTAssertTrue(notice.message.contains("sign out"))
        XCTAssertTrue(notice.message.contains("intended account"))
        XCTAssertTrue(notice.message.contains("OAuth opens the wrong Claude app"))
        XCTAssertFalse(notice.message.localizedCaseInsensitiveContains("uuid"))
    }

    func testExclusiveSetupNoticeExplainsWhyEveryOtherAppMustQuit() {
        let notice = AppNotice.exclusiveSignInRequired(profileName: "Work")

        XCTAssertEqual(notice.title, "Quit other Claude apps first")
        XCTAssertTrue(notice.message.contains("has not completed its first sign-in"))
        XCTAssertTrue(notice.message.contains("claude:// OAuth callback"))
    }

    func testCreateGuardSaysNoProfileWasCreated() {
        let notice = AppNotice.exclusiveSignInRequired()

        XCTAssertEqual(notice.title, "Quit Claude before creating a profile")
        XCTAssertTrue(notice.message.contains("No profile was created"))
    }

    func testQuarantineNoticeExplainsRecoverableBackup() {
        let notice = AppNotice.legacyIndexesBackedUp(profileName: "Work")

        XCTAssertEqual(notice.title, "Old session indexes backed up")
        XCTAssertTrue(notice.message.contains("Legacy Shared Session Indexes"))
        XCTAssertTrue(notice.message.contains("Nothing was deleted"))
        XCTAssertTrue(notice.message.contains("global transcripts were left untouched"))
        XCTAssertTrue(notice.message.contains("Show Profile Data"))
    }
}
