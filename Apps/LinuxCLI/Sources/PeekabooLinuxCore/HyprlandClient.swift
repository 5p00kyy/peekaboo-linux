import Foundation

public struct HyprlandClient: Sendable {
    private let runner: any CommandRunning

    public init(runner: any CommandRunning = FoundationProcessRunner()) {
        self.runner = runner
    }

    public func screens() throws -> [LinuxScreen] {
        let monitors: [HyprlandMonitor] = try self.decodeHyprctl("monitors")
        return monitors.map { $0.asLinuxScreen() }
    }

    public func windows() throws -> [LinuxWindow] {
        let clients: [HyprlandClientWindow] = try self.decodeHyprctl("clients")
        let activeAddress = try? self.activeWindowAddress()
        return clients.map { $0.asLinuxWindow(focusedAddress: activeAddress) }
    }

    public func activeWindowAddress() throws -> String? {
        let active: HyprlandActiveWindow = try self.decodeHyprctl("activewindow")
        guard let address = active.address, !address.isEmpty else {
            return nil
        }
        return address
    }

    private func decodeHyprctl<T: Decodable>(_ query: String) throws -> T {
        let result = try self.runner.checkedRun("hyprctl", arguments: ["-j", query])
        let data = Data(result.stdout.utf8)
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw CommandError.invalidOutput(command: "hyprctl -j \(query)", reason: String(describing: error))
        }
    }
}
