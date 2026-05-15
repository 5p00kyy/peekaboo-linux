import Foundation

#if os(Linux)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif

public struct CommandResult: Equatable, Sendable {
    public var stdout: String
    public var stderr: String
    public var exitCode: Int32

    public init(stdout: String, stderr: String, exitCode: Int32) {
        self.stdout = stdout
        self.stderr = stderr
        self.exitCode = exitCode
    }
}

public enum CommandError: Error, Equatable, LocalizedError, Sendable {
    case failed(command: String, arguments: [String], exitCode: Int32, stderr: String)
    case invalidOutput(command: String, reason: String)
    case timedOut(command: String, arguments: [String], timeoutSeconds: TimeInterval)

    public var errorDescription: String? {
        switch self {
        case let .failed(command, arguments, exitCode, stderr):
            let renderedCommand = ([command] + arguments).joined(separator: " ")
            let detail = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            if detail.isEmpty {
                return "\(renderedCommand) failed with exit code \(exitCode)"
            }
            return "\(renderedCommand) failed with exit code \(exitCode): \(detail)"
        case let .invalidOutput(command, reason):
            return "\(command) returned invalid output: \(reason)"
        case let .timedOut(command, arguments, timeoutSeconds):
            let renderedCommand = ([command] + arguments).joined(separator: " ")
            return "\(renderedCommand) timed out after \(timeoutSeconds)s"
        }
    }
}

public protocol CommandRunning: Sendable {
    func run(_ command: String, arguments: [String]) throws -> CommandResult
}

public struct FoundationProcessRunner: CommandRunning {
    private let executablePath: String
    private let timeoutSeconds: TimeInterval?

    public init(executablePath: String = "/usr/bin/env", timeoutSeconds: TimeInterval? = 10) {
        self.executablePath = executablePath
        self.timeoutSeconds = timeoutSeconds
    }

    public func run(_ command: String, arguments: [String]) throws -> CommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: self.executablePath)
        process.arguments = [command] + arguments

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        let termination = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in
            termination.signal()
        }

        try process.run()
        if let timeoutSeconds = self.timeoutSeconds {
            let waitResult = termination.wait(timeout: Self.deadline(after: timeoutSeconds))
            guard waitResult == .success else {
                Self.stop(process, termination: termination)
                throw CommandError.timedOut(command: command, arguments: arguments, timeoutSeconds: timeoutSeconds)
            }
        } else {
            process.waitUntilExit()
        }

        let stdoutData = stdout.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderr.fileHandleForReading.readDataToEndOfFile()
        return CommandResult(
            stdout: String(decoding: stdoutData, as: UTF8.self),
            stderr: String(decoding: stderrData, as: UTF8.self),
            exitCode: process.terminationStatus)
    }

    private static func deadline(after seconds: TimeInterval) -> DispatchTime {
        .now() + .milliseconds(max(1, Int(seconds * 1_000)))
    }

    private static func stop(_ process: Process, termination: DispatchSemaphore) {
        guard process.isRunning else {
            return
        }

        process.terminate()
        guard termination.wait(timeout: .now() + .seconds(1)) == .timedOut else {
            return
        }

        #if os(Linux) || canImport(Darwin)
        kill(process.processIdentifier, SIGKILL)
        _ = termination.wait(timeout: .now() + .seconds(1))
        #endif
    }
}

public extension CommandRunning {
    func checkedRun(_ command: String, arguments: [String]) throws -> CommandResult {
        let result = try self.run(command, arguments: arguments)
        guard result.exitCode == 0 else {
            throw CommandError.failed(
                command: command,
                arguments: arguments,
                exitCode: result.exitCode,
                stderr: result.stderr)
        }
        return result
    }
}
