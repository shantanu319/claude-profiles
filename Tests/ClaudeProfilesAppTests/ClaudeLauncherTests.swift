import ClaudeProfilesCore
import XCTest
@testable import ClaudeProfilesApp

final class ClaudeLauncherTests: XCTestCase {
    @MainActor
    func testManagedProcessRequiresExactAppAndDataPaths() throws {
        let root = FileManager.default.temporaryDirectory.appending(
            path: "ClaudeLauncherTests-\(UUID().uuidString)"
        )
        let paths = ProfilePaths(rootURL: root, applicationSupportURL: root)
        let repository = ProfileRepository(paths: paths)
        let launcher = ClaudeLauncher(repository: repository)
        let profile = ClaudeProfile(name: "Work")
        let executable = paths.appExecutableURL(for: profile).path
        let userData = paths.userDataURL(for: profile).path

        let exact = ClaudeProcess(
            pid: 1,
            executablePath: executable,
            userDataPath: userData,
            isolatesClaudeCode: true
        )
        XCTAssertEqual(launcher.process(for: profile, in: [exact]), exact)
        XCTAssertFalse(launcher.isLegacy(exact, for: profile))

        let preIsolation = ClaudeProcess(pid: 4, executablePath: executable, userDataPath: userData)
        XCTAssertEqual(launcher.process(for: profile, in: [preIsolation]), preIsolation)
        XCTAssertTrue(launcher.isLegacy(preIsolation, for: profile))

        let wrongData = ClaudeProcess(pid: 2, executablePath: executable, userDataPath: nil)
        XCTAssertEqual(launcher.process(for: profile, in: [wrongData]), wrongData)
        XCTAssertTrue(launcher.isLegacy(wrongData, for: profile))

        let sharedApp = ClaudeProcess(
            pid: 3,
            executablePath: "/Applications/Claude.app/Contents/MacOS/Claude",
            userDataPath: userData
        )
        XCTAssertEqual(launcher.process(for: profile, in: [sharedApp]), sharedApp)
        XCTAssertTrue(launcher.isLegacy(sharedApp, for: profile))
    }

    @MainActor
    func testManagedEnvironmentIsolatesClaudeCodeConfig() {
        let root = FileManager.default.temporaryDirectory.appending(
            path: "ClaudeLauncherTests-\(UUID().uuidString)"
        )
        let paths = ProfilePaths(rootURL: root, applicationSupportURL: root)
        let launcher = ClaudeLauncher(repository: ProfileRepository(paths: paths))
        let profile = ClaudeProfile(name: "Work")
        let otherProfile = ClaudeProfile(name: "Personal")

        XCTAssertEqual(launcher.managedEnvironment(for: profile), [
            "CLAUDE_CONFIG_DIR": paths.claudeConfigURL(for: profile).path,
            "DISABLE_UPDATE_CHECK": "1",
        ])
        XCTAssertTrue(paths.claudeConfigURL(for: profile).path.hasPrefix("/"))
        XCTAssertNotEqual(
            launcher.managedEnvironment(for: profile)["CLAUDE_CONFIG_DIR"],
            launcher.managedEnvironment(for: otherProfile)["CLAUDE_CONFIG_DIR"]
        )
    }
}
