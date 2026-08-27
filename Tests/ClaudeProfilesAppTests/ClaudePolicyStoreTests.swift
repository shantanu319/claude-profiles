import ClaudeProfilesCore
import XCTest
@testable import ClaudeProfilesApp

final class ClaudePolicyStoreTests: XCTestCase {
    private var root: URL!
    private var paths: ProfilePaths!
    private var profile: ClaudeProfile!

    override func setUp() {
        super.setUp()
        root = FileManager.default.temporaryDirectory.appending(
            path: "ClaudePolicyTests-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        paths = ProfilePaths(rootURL: root, applicationSupportURL: root)
        profile = ClaudeProfile(name: "Test")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: root)
        super.tearDown()
    }

    func testCreatesACompletePrivateUpdaterPolicy() throws {
        try ClaudePolicyStore(paths: paths, fileManager: .default)
            .disableAutoUpdates(for: profile)

        let library = policyLibraryURL
        let meta = try dictionary(at: library.appending(path: "_meta.json"))
        let identifier = try XCTUnwrap(meta["appliedId"] as? String)
        XCTAssertEqual(identifier, identifier.lowercased())
        XCTAssertNotNil(UUID(uuidString: identifier))
        let entries = try XCTUnwrap(meta["entries"] as? [[String: Any]])
        XCTAssertEqual(entries.first?["id"] as? String, identifier)
        let config = try dictionary(at: library.appending(path: "\(identifier).json"))
        XCTAssertEqual(config["disableAutoUpdates"] as? Bool, true)
        try assertPermissions(library, equalTo: 0o700)
        try assertPermissions(library.appending(path: "_meta.json"), equalTo: 0o600)
    }

    func testPreservesExistingMetadataAndConfiguration() throws {
        let identifier = UUID().uuidString.lowercased()
        try FileManager.default.createDirectory(
            at: policyLibraryURL,
            withIntermediateDirectories: true
        )
        try write(["appliedId": identifier,
                   "entries": [["id": identifier, "name": "Company"]],
                   "futureMeta": 7], to: policyLibraryURL.appending(path: "_meta.json"))
        try write(["futureSetting": "keep", "disableAutoUpdates": false],
                  to: policyLibraryURL.appending(path: "\(identifier).json"))

        try ClaudePolicyStore(paths: paths, fileManager: .default)
            .disableAutoUpdates(for: profile)

        let meta = try dictionary(at: policyLibraryURL.appending(path: "_meta.json"))
        let config = try dictionary(at: policyLibraryURL.appending(path: "\(identifier).json"))
        XCTAssertEqual(meta["futureMeta"] as? Int, 7)
        XCTAssertEqual((meta["entries"] as? [[String: Any]])?.first?["name"] as? String, "Company")
        XCTAssertEqual(config["futureSetting"] as? String, "keep")
        XCTAssertEqual(config["disableAutoUpdates"] as? Bool, true)
    }

    private var policyLibraryURL: URL {
        URL(fileURLWithPath: paths.userDataURL(for: profile).path + "-3p")
            .appending(path: "configLibrary")
    }

    private func dictionary(at url: URL) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
    }

    private func write(_ value: [String: Any], to url: URL) throws {
        try JSONSerialization.data(withJSONObject: value).write(to: url)
    }

    private func assertPermissions(_ url: URL, equalTo expected: Int) throws {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let permissions = try XCTUnwrap(attributes[.posixPermissions] as? NSNumber)
        XCTAssertEqual(permissions.intValue & 0o777, expected)
    }
}
