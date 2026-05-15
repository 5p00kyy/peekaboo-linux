import PeekabooLinuxCore
import PeekabooTypes
import Testing

@Suite("grim capture service")
struct GrimCaptureServiceTests {
    @Test("captures full screen to output path")
    func capturesScreen() throws {
        let recorder = RecordingRunner()
        try GrimCaptureService(runner: recorder).captureScreen(outputPath: "/tmp/shot.png")

        #expect(recorder.commands == [
            RecordedCommand(command: "grim", arguments: ["/tmp/shot.png"]),
        ])
    }

    @Test("captures screen by monitor name")
    func capturesScreenByMonitor() throws {
        let recorder = RecordingRunner()
        try GrimCaptureService(runner: recorder).captureScreen(outputPath: "/tmp/shot.png", screenName: "DP-1")

        #expect(recorder.commands == [
            RecordedCommand(command: "grim", arguments: ["-o", "DP-1", "/tmp/shot.png"]),
        ])
    }

    @Test("captures standardized area")
    func capturesArea() throws {
        let recorder = RecordingRunner()
        try GrimCaptureService(runner: recorder).captureArea(
            PBRect(x: 100, y: 50, width: -40, height: -20),
            outputPath: "/tmp/area.png")

        #expect(recorder.commands == [
            RecordedCommand(command: "grim", arguments: ["-g", "60,30 40x20", "/tmp/area.png"]),
        ])
    }
}

struct RecordedCommand: Equatable, Sendable {
    var command: String
    var arguments: [String]
}

final class RecordingRunner: CommandRunning, @unchecked Sendable {
    private(set) var commands: [RecordedCommand] = []

    func run(_ command: String, arguments: [String]) throws -> CommandResult {
        self.commands.append(RecordedCommand(command: command, arguments: arguments))
        return CommandResult(stdout: "", stderr: "", exitCode: 0)
    }
}
