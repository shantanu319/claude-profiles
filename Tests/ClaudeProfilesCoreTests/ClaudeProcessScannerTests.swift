import XCTest
@testable import ClaudeProfilesCore

final class ClaudeProcessScannerTests: XCTestCase {
    func testParsesOnlyMainClaudeProcesses() {
        let executable = "/Applications/Claude.app/Contents/MacOS/Claude"
        let output = """
          101 /Applications/Claude.app/Contents/MacOS/Claude
          202 /Applications/Claude.app/Contents/MacOS/Claude --user-data-dir=/Users/A/Claude Profiles/One --foo=bar
          203 /Applications/Claude.app/Contents/Frameworks/Claude Helper.app/Claude Helper --user-data-dir=/tmp
          204 /bin/zsh -c /Applications/Claude.app/Contents/MacOS/Claude
        """

        XCTAssertEqual(
            ClaudeProcessScanner.parse(output, executablePath: executable),
            [
                ClaudeProcess(pid: 101, userDataPath: nil),
                ClaudeProcess(pid: 202, userDataPath: "/Users/A/Claude Profiles/One"),
            ]
        )
    }

    func testIgnoresAPathPrefixThatIsNotTheExecutable() {
        let executable = "/Applications/Claude.app/Contents/MacOS/Claude"
        let output = "301 /Applications/Claude.app/Contents/MacOS/Claude-old --user-data-dir=/tmp"

        XCTAssertTrue(ClaudeProcessScanner.parse(output, executablePath: executable).isEmpty)
    }
}
