import Foundation

public struct ToolStatus: Codable, Equatable, Sendable {
    public var name: String
    public var available: Bool
    public var path: String?
    public var requiredForMVP: Bool

    public init(name: String, available: Bool, path: String?, requiredForMVP: Bool) {
        self.name = name
        self.available = available
        self.path = path
        self.requiredForMVP = requiredForMVP
    }
}

public struct ToolDoctor: Sendable {
    private let runner: any CommandRunning

    public init(runner: any CommandRunning = FoundationProcessRunner()) {
        self.runner = runner
    }

    public func statuses() -> [ToolStatus] {
        [
            self.status(for: "hyprctl", requiredForMVP: true),
            self.status(for: "grim", requiredForMVP: true),
            self.status(for: "slurp", requiredForMVP: false),
            self.status(for: "wl-copy", requiredForMVP: false),
            self.status(for: "wl-paste", requiredForMVP: false),
            self.status(for: "wtype", requiredForMVP: false),
            self.status(for: "ydotool", requiredForMVP: false),
        ]
    }

    private func status(for tool: String, requiredForMVP: Bool) -> ToolStatus {
        guard let result = try? self.runner.run("which", arguments: [tool]), result.exitCode == 0 else {
            return ToolStatus(name: tool, available: false, path: nil, requiredForMVP: requiredForMVP)
        }

        let path = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        return ToolStatus(name: tool, available: !path.isEmpty, path: path.isEmpty ? nil : path, requiredForMVP: requiredForMVP)
    }
}
