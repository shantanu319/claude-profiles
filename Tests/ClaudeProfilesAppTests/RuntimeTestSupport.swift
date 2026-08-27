import AppKit
import ClaudeProfilesCore
import Foundation

enum RuntimeIntegrationError: Error {
    case processDidNotLaunch
    case processDidNotExit
}

extension ClaudeRuntimeIntegrationTests {
    @MainActor
    func waitForProcess(at executable: String) async throws -> ClaudeProcess {
        let scanner = ClaudeProcessScanner(executablePath: executable)
        for _ in 0..<200 {
            if let process = try scanner.snapshot().first {
                return process
            }
            try await Task.sleep(for: .milliseconds(100))
        }
        throw RuntimeIntegrationError.processDidNotLaunch
    }

    @MainActor
    func waitForExit(_ pid: pid_t) async throws {
        for _ in 0..<200 {
            guard let application = NSRunningApplication(processIdentifier: pid),
                  !application.isTerminated else {
                return
            }
            try await Task.sleep(for: .milliseconds(100))
        }
        NSRunningApplication(processIdentifier: pid)?.forceTerminate()
        throw RuntimeIntegrationError.processDidNotExit
    }
}
