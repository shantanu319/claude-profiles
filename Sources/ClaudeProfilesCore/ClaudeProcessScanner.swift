import Foundation

public struct ClaudeProcess: Equatable, Sendable {
    public let pid: pid_t
    public let userDataPath: String?

    public init(pid: pid_t, userDataPath: String?) {
        self.pid = pid
        self.userDataPath = userDataPath
    }
}

public enum ProcessScanError: LocalizedError {
    case commandFailed

    public var errorDescription: String? {
        "Could not inspect running Claude windows."
    }
}

public struct ClaudeProcessScanner: Sendable {
    public let executablePath: String

    public init(executablePath: String = "/Applications/Claude.app/Contents/MacOS/Claude") {
        self.executablePath = executablePath
    }

    public func snapshot() throws -> [ClaudeProcess] {
        let task = Process()
        let pipe = Pipe()
        task.executableURL = URL(fileURLWithPath: "/bin/ps")
        task.arguments = ["-axo", "pid=,command="]
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        try task.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()
        guard task.terminationStatus == 0 else { throw ProcessScanError.commandFailed }
        let output = String(decoding: data, as: UTF8.self)
        return Self.parse(output, executablePath: executablePath)
    }

    public static func parse(_ output: String, executablePath: String) -> [ClaudeProcess] {
        output.split(separator: "\n").compactMap { rawLine in
            let line = rawLine.drop(while: { $0.isWhitespace })
            guard let split = line.firstIndex(where: { $0.isWhitespace }) else { return nil }
            guard let pid = pid_t(line[..<split]) else { return nil }
            let command = line[split...].drop(while: { $0.isWhitespace })
            guard command == executablePath || command.hasPrefix(executablePath + " ") else {
                return nil
            }
            return ClaudeProcess(pid: pid, userDataPath: userDataPath(in: command))
        }
    }

    private static func userDataPath(in command: Substring) -> String? {
        let marker = "--user-data-dir="
        guard let markerRange = command.range(of: marker) else { return nil }
        let remainder = command[markerRange.upperBound...]
        let end = remainder.range(of: " --")?.lowerBound ?? remainder.endIndex
        return String(remainder[..<end])
    }
}
