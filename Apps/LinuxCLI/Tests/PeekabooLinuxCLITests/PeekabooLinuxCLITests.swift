import Foundation
import PeekabooLinuxCLI
import PeekabooLinuxCore
import Testing

@Suite("peekaboo-linux CLI")
struct PeekabooLinuxCLITests {
    @Test("prints usage when command is missing")
    func missingCommand() {
        let output = OutputCapture()
        let cli = PeekabooLinuxCLI(output: output.stdout, errorOutput: output.stderr)

        let exitCode = cli.run(arguments: [])

        #expect(exitCode == 64)
        #expect(output.errors.joined(separator: "\n").contains("missing command"))
    }

    @Test("prints version")
    func version() {
        let output = OutputCapture()
        let cli = PeekabooLinuxCLI(output: output.stdout, errorOutput: output.stderr)

        let exitCode = cli.run(arguments: ["--version"])

        #expect(exitCode == 0)
        #expect(output.lines == ["peekaboo-linux 0.1.0"])
        #expect(output.errors.isEmpty)
    }

    @Test("captures area image")
    func imageArea() {
        let output = OutputCapture()
        let runner = CLIRecordingRunner()
        let cli = PeekabooLinuxCLI(
            capture: GrimCaptureService(runner: runner),
            output: output.stdout,
            errorOutput: output.stderr)

        let exitCode = cli.run(arguments: [
            "image",
            "--mode",
            "area",
            "--rect",
            "100,50,-40,-20",
            "--path",
            "/tmp/area.png",
        ])

        #expect(exitCode == 0)
        #expect(output.lines == ["/tmp/area.png"])
        #expect(runner.commands == [
            CLIRecordedCommand(command: "grim", arguments: ["-g", "60,30 40x20", "/tmp/area.png"]),
        ])
    }
}

final class OutputCapture: @unchecked Sendable {
    private(set) var lines: [String] = []
    private(set) var errors: [String] = []

    func stdout(_ line: String) {
        self.lines.append(line)
    }

    func stderr(_ line: String) {
        self.errors.append(line)
    }
}

struct CLIRecordedCommand: Equatable, Sendable {
    var command: String
    var arguments: [String]
}

final class CLIRecordingRunner: CommandRunning, @unchecked Sendable {
    private(set) var commands: [CLIRecordedCommand] = []

    func run(_ command: String, arguments: [String]) throws -> CommandResult {
        self.commands.append(CLIRecordedCommand(command: command, arguments: arguments))
        return CommandResult(stdout: "", stderr: "", exitCode: 0)
    }
}
