import Foundation
import PeekabooTypes

public struct LinuxScreen: Codable, Equatable, Sendable {
    public var id: Int
    public var name: String
    public var description: String?
    public var frame: PBRect
    public var scale: Double
    public var focused: Bool
    public var activeWorkspace: String?

    public init(
        id: Int,
        name: String,
        description: String?,
        frame: PBRect,
        scale: Double,
        focused: Bool,
        activeWorkspace: String?)
    {
        self.id = id
        self.name = name
        self.description = description
        self.frame = frame
        self.scale = scale
        self.focused = focused
        self.activeWorkspace = activeWorkspace
    }
}

public struct LinuxWindow: Codable, Equatable, Sendable {
    public var id: PlatformWindowID
    public var address: String
    public var title: String
    public var appID: String
    public var pid: Int?
    public var frame: PBRect
    public var workspace: String?
    public var monitor: Int?
    public var floating: Bool
    public var focused: Bool
    public var xwayland: Bool

    public init(
        id: PlatformWindowID,
        address: String,
        title: String,
        appID: String,
        pid: Int?,
        frame: PBRect,
        workspace: String?,
        monitor: Int?,
        floating: Bool,
        focused: Bool,
        xwayland: Bool)
    {
        self.id = id
        self.address = address
        self.title = title
        self.appID = appID
        self.pid = pid
        self.frame = frame
        self.workspace = workspace
        self.monitor = monitor
        self.floating = floating
        self.focused = focused
        self.xwayland = xwayland
    }
}

struct HyprlandWorkspace: Decodable, Equatable, Sendable {
    var id: Int?
    var name: String?
}

struct HyprlandMonitor: Decodable, Equatable, Sendable {
    var id: Int
    var name: String
    var description: String?
    var width: Int
    var height: Int
    var x: Int
    var y: Int
    var scale: Double
    var focused: Bool
    var activeWorkspace: HyprlandWorkspace?

    func asLinuxScreen() -> LinuxScreen {
        LinuxScreen(
            id: self.id,
            name: self.name,
            description: self.description,
            frame: PBRect(
                x: Double(self.x),
                y: Double(self.y),
                width: Double(self.width),
                height: Double(self.height)),
            scale: self.scale,
            focused: self.focused,
            activeWorkspace: self.activeWorkspace?.name)
    }
}

struct HyprlandClientWindow: Decodable, Equatable, Sendable {
    var address: String
    var mapped: Bool?
    var hidden: Bool?
    var at: [Int]
    var size: [Int]
    var workspace: HyprlandWorkspace?
    var floating: Bool?
    var monitor: Int?
    var `class`: String?
    var title: String?
    var pid: Int?
    var xwayland: Bool?

    func asLinuxWindow(focusedAddress: String?) -> LinuxWindow {
        let originX = self.at.first ?? 0
        let originY = self.at.dropFirst().first ?? 0
        let width = self.size.first ?? 0
        let height = self.size.dropFirst().first ?? 0

        return LinuxWindow(
            id: .hyprlandAddress(self.address),
            address: self.address,
            title: self.title ?? "",
            appID: self.class ?? "",
            pid: self.pid,
            frame: PBRect(
                x: Double(originX),
                y: Double(originY),
                width: Double(width),
                height: Double(height)),
            workspace: self.workspace?.name,
            monitor: self.monitor,
            floating: self.floating ?? false,
            focused: self.address == focusedAddress,
            xwayland: self.xwayland ?? false)
    }
}

struct HyprlandActiveWindow: Decodable, Equatable, Sendable {
    var address: String?
}
