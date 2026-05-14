import Foundation

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
        }
    }
}

public protocol CommandRunning: Sendable {
    func run(_ command: String, arguments: [String]) throws -> CommandResult
}

public struct FoundationProcessRunner: CommandRunning {
    private let executablePath: String

    public init(executablePath: String = "/usr/bin/env") {
        self.executablePath = executablePath
    }

    public func run(_ command: String, arguments: [String]) throws -> CommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: self.executablePath)
        process.arguments = [command] + arguments

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()

        let stdoutData = stdout.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderr.fileHandleForReading.readDataToEndOfFile()
        return CommandResult(
            stdout: String(decoding: stdoutData, as: UTF8.self),
            stderr: String(decoding: stderrData, as: UTF8.self),
            exitCode: process.terminationStatus)
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
