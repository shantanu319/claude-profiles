import Foundation

public struct ClaudeProcess: Equatable, Sendable {
    public let pid: pid_t
    public let executablePath: String
    public let userDataPath: String?
    public let isolatesClaudeCode: Bool

    public init(
        pid: pid_t,
        executablePath: String,
        userDataPath: String?,
        isolatesClaudeCode: Bool = false
    ) {
        self.pid = pid
        self.executablePath = executablePath
        self.userDataPath = userDataPath
        self.isolatesClaudeCode = isolatesClaudeCode
    }
}

public enum ProcessScanError: LocalizedError {
    case commandFailed

    public var errorDescription: String? {
        "Could not inspect running Claude windows."
    }
}

public struct ClaudeProcessScanner: Sendable {
    public static let isolationArgument = "--claude-profiles-code-isolation=v1"
    public let executablePaths: Set<String>

    public init(executablePath: String = "/Applications/Claude.app/Contents/MacOS/Claude") {
        self.executablePaths = [executablePath]
    }

    public init(executablePaths: Set<String>) {
        self.executablePaths = executablePaths
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
        let resolvedPaths = executablePaths.map { path in
            CanonicalFilePath.resolve(path)
        }
        return Self.parse(output, executablePaths: executablePaths.union(resolvedPaths))
    }

    public static func parse(_ output: String, executablePath: String) -> [ClaudeProcess] {
        parse(output, executablePaths: [executablePath])
    }

    public static func parse(_ output: String, executablePaths: Set<String>) -> [ClaudeProcess] {
        output.split(separator: "\n").compactMap { rawLine in
            let line = rawLine.drop(while: { $0.isWhitespace })
            guard let split = line.firstIndex(where: { $0.isWhitespace }) else { return nil }
            guard let pid = pid_t(line[..<split]) else { return nil }
            let command = line[split...].drop(while: { $0.isWhitespace })
            guard let executablePath = executablePaths.first(where: {
                command == $0 || command.hasPrefix($0 + " ")
            }) else {
                return nil
            }
            return ClaudeProcess(
                pid: pid,
                executablePath: executablePath,
                userDataPath: userDataPath(in: command),
                isolatesClaudeCode: command.contains(isolationArgument)
            )
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
