import Foundation

struct CommandError: LocalizedError, Sendable {
    let executable: String
    let status: Int32
    let errorOutput: String

    var errorDescription: String? {
        let detail = errorOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        return detail.isEmpty
            ? "\(executable) failed with status \(status)."
            : "\(executable) failed: \(detail)"
    }
}

enum AsyncCommand {
    static func run(executable: URL, arguments: [String]) async throws {
        try await Task.detached(priority: .userInitiated) {
            let process = Process()
            let errorPipe = Pipe()
            process.executableURL = executable
            process.arguments = arguments
            process.standardOutput = FileHandle.nullDevice
            process.standardError = errorPipe
            try process.run()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else {
                throw CommandError(
                    executable: executable.lastPathComponent,
                    status: process.terminationStatus,
                    errorOutput: String(decoding: errorData, as: UTF8.self)
                )
            }
        }.value
    }
}
