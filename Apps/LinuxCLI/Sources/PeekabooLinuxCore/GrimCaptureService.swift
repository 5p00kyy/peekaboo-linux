import Foundation
import PeekabooTypes

public struct GrimCaptureService: Sendable {
    private let runner: any CommandRunning

    public init(runner: any CommandRunning = FoundationProcessRunner()) {
        self.runner = runner
    }

    public func captureScreen(outputPath: String, screenName: String? = nil) throws {
        var arguments: [String] = []
        if let screenName, !screenName.isEmpty {
            arguments.append(contentsOf: ["-o", screenName])
        }
        arguments.append(outputPath)
        _ = try self.runner.checkedRun("grim", arguments: arguments)
    }

    public func captureArea(_ rect: PBRect, outputPath: String) throws {
        let standardized = rect.standardized
        let geometry = "\(Int(standardized.x)),\(Int(standardized.y)) " +
            "\(Int(standardized.width))x\(Int(standardized.height))"
        _ = try self.runner.checkedRun("grim", arguments: ["-g", geometry, outputPath])
    }
}
