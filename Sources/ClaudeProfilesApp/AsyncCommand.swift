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
        let command = RunningCommand(executable: executable, arguments: arguments)
        try await withTaskCancellationHandler {
            try Task.checkCancellation()
            try command.start()
            let errorTask = Task.detached(priority: .utility) {
                command.readErrorOutput()
            }

            do {
                while command.isRunning {
                    try await Task.sleep(for: .milliseconds(50))
                }
                command.waitUntilExit()
                let errorData = await errorTask.value
                guard command.terminationStatus == 0 else {
                    throw CommandError(
                        executable: executable.lastPathComponent,
                        status: command.terminationStatus,
                        errorOutput: String(decoding: errorData, as: UTF8.self)
                    )
                }
            } catch {
                command.cancel()
                command.waitUntilExit()
                _ = await errorTask.value
                throw error
            }
        } onCancel: {
            command.cancel()
        }
    }
}

private final class RunningCommand: @unchecked Sendable {
    private let process = Process()
    private let errorPipe = Pipe()
    private let lock = NSLock()
    private var cancelled = false
    private var started = false

    init(executable: URL, arguments: [String]) {
        process.executableURL = executable
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = errorPipe
    }

    func start() throws {
        lock.lock()
        defer { lock.unlock() }
        guard !cancelled else { throw CancellationError() }
        try process.run()
        started = true
        errorPipe.fileHandleForWriting.closeFile()
    }

    func cancel() {
        lock.lock()
        cancelled = true
        if started && process.isRunning {
            process.terminate()
        }
        lock.unlock()
    }

    var isRunning: Bool {
        lock.lock()
        defer { lock.unlock() }
        return process.isRunning
    }

    var terminationStatus: Int32 {
        process.terminationStatus
    }

    func waitUntilExit() {
        process.waitUntilExit()
    }

    func readErrorOutput() -> Data {
        errorPipe.fileHandleForReading.readDataToEndOfFile()
    }
}
