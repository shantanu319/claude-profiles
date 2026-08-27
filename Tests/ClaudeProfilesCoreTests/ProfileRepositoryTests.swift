import XCTest
@testable import ClaudeProfilesCore

final class ProfileRepositoryTests: XCTestCase {
    private var temporaryURL: URL!
    private var paths: ProfilePaths!

    override func setUp() {
        super.setUp()
        temporaryURL = FileManager.default.temporaryDirectory
            .appending(path: "ClaudeProfilesTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        paths = ProfilePaths(
            rootURL: temporaryURL.appending(path: "Store", directoryHint: .isDirectory),
            applicationSupportURL: temporaryURL
        )
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: temporaryURL)
        super.tearDown()
    }

    func testCreatePersistsSecureDirectories() throws {
        let repository = ProfileRepository(paths: paths)
        let profiles = try repository.create(named: "Work", in: [])

        let loaded = try repository.load()
        XCTAssertEqual(loaded.map(\.id), profiles.map(\.id))
        XCTAssertEqual(loaded[0].createdAt.timeIntervalSince1970,
                       profiles[0].createdAt.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertEqual(profiles.map(\.name), ["Work"])
        try assertSecureDirectory(paths.userDataURL(for: profiles[0]))
    }

    func testDeleteMovesContainerAndUpdatesRegistry() throws {
        let destination = paths.rootURL.appending(path: "trashed", directoryHint: .isDirectory)
        let repository = ProfileRepository(paths: paths) { source in
            try FileManager.default.moveItem(at: source, to: destination)
        }
        let profiles = try repository.create(named: "Personal", in: [])

        let updated = try repository.delete(profiles[0], from: profiles)

        XCTAssertTrue(updated.isEmpty)
        XCTAssertTrue(try repository.load().isEmpty)
        XCTAssertTrue(FileManager.default.fileExists(atPath: destination.path))
    }

    func testFailedRegistryWriteRemovesTheNewProfileDirectory() throws {
        try FileManager.default.createDirectory(
            at: paths.registryURL,
            withIntermediateDirectories: true
        )
        let repository = ProfileRepository(paths: paths)

        XCTAssertThrowsError(try repository.create(named: "Work", in: []))
        let entries = try FileManager.default.contentsOfDirectory(
            at: paths.profilesURL,
            includingPropertiesForKeys: nil
        )
        XCTAssertTrue(entries.isEmpty)
    }

    private func assertSecureDirectory(_ url: URL) throws {
        var isDirectory: ObjCBool = false
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory))
        XCTAssertTrue(isDirectory.boolValue)
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let permissions = try XCTUnwrap(attributes[.posixPermissions] as? NSNumber)
        XCTAssertEqual(permissions.intValue & 0o777, 0o700)
    }
}
