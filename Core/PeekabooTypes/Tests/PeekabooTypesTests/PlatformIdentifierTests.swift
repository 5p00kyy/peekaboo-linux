import Foundation
import Testing

@testable import PeekabooTypes

@Suite("Platform identifiers")
struct PlatformIdentifierTests {
    @Test("encodes Hyprland window addresses without integer coercion")
    func encodesHyprlandAddress() throws {
        let id = PlatformWindowID.hyprlandAddress("0x5beef")
        let data = try JSONEncoder().encode(id)
        let json = try #require(String(data: data, encoding: .utf8))

        #expect(json.contains("\"platform\":\"hyprland-address\""))
        #expect(json.contains("\"value\":\"0x5beef\""))
    }

    @Test("decodes known platform IDs")
    func decodesKnownIDs() throws {
        let data = Data(#"{"platform":"x11-window","value":"12345"}"#.utf8)
        let id = try JSONDecoder().decode(PlatformWindowID.self, from: data)

        #expect(id == .x11Window(12345))
    }

    @Test("keeps unknown platform IDs opaque")
    func keepsUnknownIDsOpaque() throws {
        let data = Data(#"{"platform":"future-compositor","value":"abc"}"#.utf8)
        let id = try JSONDecoder().decode(PlatformWindowID.self, from: data)

        #expect(id == .opaque(platform: "future-compositor", value: "abc"))
    }
}

