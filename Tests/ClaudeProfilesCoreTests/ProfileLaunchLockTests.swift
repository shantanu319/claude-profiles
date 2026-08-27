import XCTest
@testable import ClaudeProfilesCore

final class ProfileLaunchLockTests: XCTestCase {
    private var root: URL!

    override func setUp() {
        root = FileManager.default.temporaryDirectory.appending(
            path: "ProfileLaunchLockTests-\(UUID().uuidString)"
        )
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: root)
    }

    func testOnlyOneOwnerCanHoldAProfileLock() throws {
        let url = root.appending(path: "launch.lock")
        let first = try ProfileLaunchLock(at: url)

        XCTAssertThrowsError(try ProfileLaunchLock(at: url)) { error in
            XCTAssertEqual(error as? ProfileError, .profileIsOpening)
        }

        first.unlock()
        let next = try ProfileLaunchLock(at: url)
        next.unlock()
    }
}
