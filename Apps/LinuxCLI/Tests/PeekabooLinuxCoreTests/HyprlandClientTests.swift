import PeekabooLinuxCore
import PeekabooTypes
import Testing

@Suite("Hyprland client")
struct HyprlandClientTests {
    @Test("decodes monitors into portable screen geometry")
    func decodesMonitors() throws {
        let runner = StubRunner(outputs: [
            StubRunner.key("hyprctl", ["-j", "monitors"]): .success("""
            [
              {
                "id": 0,
                "name": "DP-1",
                "description": "Test Display",
                "width": 3440,
                "height": 1440,
                "x": 0,
                "y": 0,
                "scale": 1.0,
                "focused": true,
                "activeWorkspace": { "id": 1, "name": "1" }
              }
            ]
            """),
        ])

        let screens = try HyprlandClient(runner: runner).screens()

        #expect(screens == [
            LinuxScreen(
                id: 0,
                name: "DP-1",
                description: "Test Display",
                frame: PBRect(x: 0, y: 0, width: 3440, height: 1440),
                scale: 1.0,
                focused: true,
                activeWorkspace: "1"),
        ])
    }

    @Test("decodes windows and marks active Hyprland address")
    func decodesWindows() throws {
        let runner = StubRunner(outputs: [
            StubRunner.key("hyprctl", ["-j", "clients"]): .success("""
            [
              {
                "address": "0xabc",
                "mapped": true,
                "hidden": false,
                "at": [10, 20],
                "size": [800, 600],
                "workspace": { "id": 1, "name": "1" },
                "floating": false,
                "monitor": 0,
                "class": "Alacritty",
                "title": "shell",
                "pid": 42,
                "xwayland": false
              }
            ]
            """),
            StubRunner.key("hyprctl", ["-j", "activewindow"]): .success(#"{"address":"0xabc"}"#),
        ])

        let windows = try HyprlandClient(runner: runner).windows()

        #expect(windows == [
            LinuxWindow(
                id: .hyprlandAddress("0xabc"),
                address: "0xabc",
                title: "shell",
                appID: "Alacritty",
                pid: 42,
                frame: PBRect(x: 10, y: 20, width: 800, height: 600),
                workspace: "1",
                monitor: 0,
                floating: false,
                focused: true,
                xwayland: false),
        ])
    }
}

struct StubRunner: CommandRunning {
    enum Output: Sendable {
        case success(String)
        case failure(Int32, String)
    }

    var outputs: [String: Output]

    static func key(_ command: String, _ arguments: [String]) -> String {
        ([command] + arguments).joined(separator: "\u{1f}")
    }

    func run(_ command: String, arguments: [String]) throws -> CommandResult {
        guard let output = self.outputs[Self.key(command, arguments)] else {
            return CommandResult(stdout: "", stderr: "unexpected command", exitCode: 127)
        }

        switch output {
        case let .success(stdout):
            return CommandResult(stdout: stdout, stderr: "", exitCode: 0)
        case let .failure(code, stderr):
            return CommandResult(stdout: "", stderr: stderr, exitCode: code)
        }
    }
}
