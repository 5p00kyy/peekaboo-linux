/// Window identity without assuming a macOS CoreGraphics integer ID.
public enum PlatformWindowID: Codable, Hashable, Sendable {
    case macCGWindow(UInt32)
    case hyprlandAddress(String)
    case x11Window(UInt64)
    case opaque(platform: String, value: String)

    private enum CodingKeys: String, CodingKey {
        case platform
        case value
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let platform = try container.decode(String.self, forKey: .platform)
        let value = try container.decode(String.self, forKey: .value)

        switch platform {
        case "macos-cgwindow":
            guard let id = UInt32(value) else {
                throw DecodingError.dataCorruptedError(
                    forKey: .value,
                    in: container,
                    debugDescription: "Invalid macOS CGWindowID: \(value)")
            }
            self = .macCGWindow(id)
        case "hyprland-address":
            self = .hyprlandAddress(value)
        case "x11-window":
            guard let id = UInt64(value) else {
                throw DecodingError.dataCorruptedError(
                    forKey: .value,
                    in: container,
                    debugDescription: "Invalid X11 window ID: \(value)")
            }
            self = .x11Window(id)
        default:
            self = .opaque(platform: platform, value: value)
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let encoded = self.encodedPair
        try container.encode(encoded.platform, forKey: .platform)
        try container.encode(encoded.value, forKey: .value)
    }

    public var platform: String {
        self.encodedPair.platform
    }

    public var value: String {
        self.encodedPair.value
    }

    private var encodedPair: (platform: String, value: String) {
        switch self {
        case let .macCGWindow(id):
            ("macos-cgwindow", String(id))
        case let .hyprlandAddress(address):
            ("hyprland-address", address)
        case let .x11Window(id):
            ("x11-window", String(id))
        case let .opaque(platform, value):
            (platform, value)
        }
    }
}

