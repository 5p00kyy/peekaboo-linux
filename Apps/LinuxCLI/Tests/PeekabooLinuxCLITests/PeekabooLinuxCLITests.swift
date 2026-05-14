import Foundation
import PeekabooLinuxCLI
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
