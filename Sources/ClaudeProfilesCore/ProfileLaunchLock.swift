import Darwin
import Foundation

public final class ProfileLaunchLock {
    private var descriptor: Int32

    public init(at url: URL, fileManager: FileManager = .default) throws {
        let parent = url.deletingLastPathComponent()
        try fileManager.createDirectory(
            at: parent,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: parent.path)

        let opened = url.path.withCString {
            Darwin.open($0, O_CREAT | O_RDWR | O_EXLOCK | O_NONBLOCK, mode_t(0o600))
        }
        guard opened >= 0 else {
            let code = errno
            if code == EWOULDBLOCK || code == EAGAIN {
                throw ProfileError.profileIsOpening
            }
            throw Self.posixError(code)
        }
        descriptor = opened
    }

    public func unlock() {
        guard descriptor >= 0 else { return }
        Darwin.close(descriptor)
        descriptor = -1
    }

    deinit {
        unlock()
    }

    private static func posixError(_ code: Int32) -> POSIXError {
        POSIXError(POSIXErrorCode(rawValue: code) ?? .EIO)
    }
}
