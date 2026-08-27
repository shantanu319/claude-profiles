import XCTest
@testable import ClaudeProfilesCore

final class ProfileNameTests: XCTestCase {
    func testCleansAUniqueName() throws {
        let existing = [ClaudeProfile(name: "Personal")]
        XCTAssertEqual(try ProfileName.clean("  Work  ", existing: existing), "Work")
    }

    func testRejectsBlankName() {
        XCTAssertThrowsError(try ProfileName.clean(" \n ", existing: [])) { error in
            XCTAssertEqual(error as? ProfileError, .blankName)
        }
    }

    func testRejectsCaseInsensitiveDuplicate() {
        let existing = [ClaudeProfile(name: "Work")]
        XCTAssertThrowsError(try ProfileName.clean("work", existing: existing)) { error in
            XCTAssertEqual(error as? ProfileError, .duplicateName)
        }
    }

    func testRejectsLongName() {
        XCTAssertThrowsError(try ProfileName.clean(String(repeating: "a", count: 51), existing: [])) {
            error in
            XCTAssertEqual(error as? ProfileError, .nameTooLong)
        }
    }
}
