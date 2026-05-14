import Foundation
import PeekabooLinuxCore
import PeekabooTypes

public struct PeekabooLinuxCLI: Sendable {
    private let hyprland: HyprlandClient
    private let capture: GrimCaptureService
    private let doctor: ToolDoctor
    private let output: @Sendable (String) -> Void
    private let errorOutput: @Sendable (String) -> Void

    public init(
        hyprland: HyprlandClient = HyprlandClient(),
        capture: GrimCaptureService = GrimCaptureService(),
        doctor: ToolDoctor = ToolDoctor(),
        output: @escaping @Sendable (String) -> Void = { print($0) },
        errorOutput: @escaping @Sendable (String) -> Void = { FileHandle.standardError.write(Data(($0 + "\n").utf8)) })
    {
        self.hyprland = hyprland
        self.capture = capture
        self.doctor = doctor
        self.output = output
        self.errorOutput = errorOutput
    }

    public func run(arguments: [String]) -> Int32 {
        do {
            try self.runThrowing(arguments: arguments)
            return 0
        } catch let error as UsageError {
            self.errorOutput(error.message)
            self.errorOutput(Self.usage)
            return 64
        } catch {
            self.errorOutput(error.localizedDescription)
            return 1
        }
    }

    private func runThrowing(arguments: [String]) throws {
        var parser = ArgumentParser(arguments: arguments)
        guard let command = parser.consume() else {
            throw UsageError("missing command")
        }

        switch command {
        case "--help", "-h", "help":
            self.output(Self.usage)
        case "--version", "version":
            self.output("peekaboo-linux 0.1.0")
        case "doctor":
            try self.handleDoctor(parser: &parser)
        case "list":
            try self.handleList(parser: &parser)
        case "image":
            try self.handleImage(parser: &parser)
        default:
            throw UsageError("unknown command: \(command)")
        }

        guard parser.remaining.isEmpty else {
            throw UsageError("unexpected arguments: \(parser.remaining.joined(separator: " "))")
        }
    }

    private func handleDoctor(parser: inout ArgumentParser) throws {
        let json = parser.consumeFlag("--json")
        let statuses = self.doctor.statuses()
        if json {
            try self.outputJSON(statuses)
        } else {
            for status in statuses {
                let marker = status.available ? "ok" : "missing"
                let required = status.requiredForMVP ? "required" : "optional"
                let location = status.path.map { " \($0)" } ?? ""
                self.output("\(marker) \(status.name) \(required)\(location)")
            }
        }
    }

    private func handleList(parser: inout ArgumentParser) throws {
        guard let target = parser.consume() else {
            throw UsageError("list requires a target: screens or windows")
        }
        let json = parser.consumeFlag("--json")

        switch target {
        case "screens":
            let screens = try self.hyprland.screens()
            if json {
                try self.outputJSON(screens)
            } else {
                for screen in screens {
                    let focused = screen.focused ? " focused" : ""
                    self.output(
                        "\(screen.id) \(screen.name) " +
                            "\(Int(screen.frame.width))x\(Int(screen.frame.height))" +
                            "+\(Int(screen.frame.x)),\(Int(screen.frame.y)) scale=\(screen.scale)\(focused)")
                }
            }
        case "windows":
            let windows = try self.hyprland.windows()
            if json {
                try self.outputJSON(windows)
            } else {
                for window in windows {
                    let focused = window.focused ? " focused" : ""
                    self.output(
                        "\(window.address) \(window.appID) " +
                            "\"\(window.title)\" " +
                            "\(Int(window.frame.width))x\(Int(window.frame.height))" +
                            "+\(Int(window.frame.x)),\(Int(window.frame.y))\(focused)")
                }
            }
        default:
            throw UsageError("unknown list target: \(target)")
        }
    }

    private func handleImage(parser: inout ArgumentParser) throws {
        let mode = try parser.consumeOption("--mode") ?? "screen"
        let path = try parser.requireOption("--path")
        let screen = try parser.consumeOption("--screen")

        switch mode {
        case "screen":
            try self.capture.captureScreen(outputPath: path, screenName: screen)
            self.output(path)
        case "area":
            let rect = try Self.parseRect(try parser.requireOption("--rect"))
            try self.capture.captureArea(rect, outputPath: path)
            self.output(path)
        default:
            throw UsageError("unsupported image mode: \(mode)")
        }
    }

    private static func parseRect(_ value: String) throws -> PBRect {
        let parts = value.split(separator: ",", omittingEmptySubsequences: false)
        guard parts.count == 4 else {
            throw UsageError("--rect must use x,y,width,height")
        }

        guard
            let x = Double(parts[0]),
            let y = Double(parts[1]),
            let width = Double(parts[2]),
            let height = Double(parts[3])
        else {
            throw UsageError("--rect values must be numbers")
        }

        return PBRect(x: x, y: y, width: width, height: height)
    }

    private func outputJSON<T: Encodable>(_ value: T) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(value)
        self.output(String(decoding: data, as: UTF8.self))
    }

    static let usage = """
    Usage:
      peekaboo-linux doctor [--json]
      peekaboo-linux list screens [--json]
      peekaboo-linux list windows [--json]
      peekaboo-linux image --mode screen --path PATH [--screen NAME]
      peekaboo-linux image --mode area --rect X,Y,WIDTH,HEIGHT --path PATH
      peekaboo-linux --version
    """
}

struct UsageError: Error, Equatable {
    var message: String

    init(_ message: String) {
        self.message = message
    }
}

struct ArgumentParser {
    private(set) var remaining: [String]

    init(arguments: [String]) {
        self.remaining = arguments
    }

    mutating func consume() -> String? {
        guard !self.remaining.isEmpty else { return nil }
        return self.remaining.removeFirst()
    }

    mutating func consumeFlag(_ name: String) -> Bool {
        guard let index = self.remaining.firstIndex(of: name) else {
            return false
        }
        self.remaining.remove(at: index)
        return true
    }

    mutating func consumeOption(_ name: String) throws -> String? {
        guard let index = self.remaining.firstIndex(of: name) else {
            return nil
        }
        let valueIndex = self.remaining.index(after: index)
        guard valueIndex < self.remaining.endIndex else {
            throw UsageError("\(name) requires a value")
        }
        let value = self.remaining[valueIndex]
        self.remaining.remove(at: valueIndex)
        self.remaining.remove(at: index)
        return value
    }

    mutating func requireOption(_ name: String) throws -> String {
        guard let value = try self.consumeOption(name) else {
            throw UsageError("\(name) is required")
        }
        return value
    }
}
