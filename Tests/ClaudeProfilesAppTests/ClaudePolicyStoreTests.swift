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

    func testEstablishmentRequiresReceiptAndAnEnabledPolicy() throws {
        let identity = Data([1, 2, 3])
        let store = ClaudePolicyStore(paths: paths, fileManager: .default)

        XCTAssertFalse(try store.isEstablished(for: profile, identity: identity))
        try store.establish(for: profile, identity: identity)
        XCTAssertTrue(try store.isEstablished(for: profile, identity: identity))
        XCTAssertFalse(try store.isEstablished(for: profile, identity: Data([9])))

        let meta = try dictionary(at: policyLibraryURL.appending(path: "_meta.json"))
        let identifier = try XCTUnwrap(meta["appliedId"] as? String)
        try write(["disableAutoUpdates": false],
                  to: policyLibraryURL.appending(path: "\(identifier).json"))
        XCTAssertFalse(try store.isEstablished(for: profile, identity: identity))
    }

    func testRestartRequirementPersistsUntilCleared() throws {
        let store = ClaudePolicyStore(paths: paths, fileManager: .default)
        try FileManager.default.createDirectory(
            at: paths.containerURL(for: profile),
            withIntermediateDirectories: true
        )

        XCTAssertFalse(store.requiresRestart(for: profile))
        try store.markRestartRequired(for: profile)
        XCTAssertTrue(store.requiresRestart(for: profile))
        try store.clearRestartRequirement(for: profile)
        XCTAssertFalse(store.requiresRestart(for: profile))
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
