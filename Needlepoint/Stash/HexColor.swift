import Foundation

/// An sRGB color stored as `#rrggbb`, the format the web app saved swatches in.
nonisolated struct HexColor: Equatable, Sendable {
    /// Components in 0...1.
    let red: Double
    let green: Double
    let blue: Double

    /// Accepts `#rrggbb` or `rrggbb` in any case, with surrounding whitespace.
    init?(_ string: String) {
        var hex = Substring(string.trimmingCharacters(in: .whitespacesAndNewlines))
        if hex.hasPrefix("#") { hex = hex.dropFirst() }
        guard hex.count == 6, let value = UInt32(hex, radix: 16) else { return nil }
        self.init(
            red: Double((value >> 16) & 0xff) / 255,
            green: Double((value >> 8) & 0xff) / 255,
            blue: Double(value & 0xff) / 255)
    }

    init(red: Double, green: Double, blue: Double) {
        self.red = Self.clamp(red)
        self.green = Self.clamp(green)
        self.blue = Self.clamp(blue)
    }

    var string: String {
        String(format: "#%02x%02x%02x", Self.byte(red), Self.byte(green), Self.byte(blue))
    }

    static func == (lhs: HexColor, rhs: HexColor) -> Bool {
        lhs.string == rhs.string
    }

    private static func clamp(_ value: Double) -> Double { min(1, max(0, value)) }
    private static func byte(_ value: Double) -> Int { Int((value * 255).rounded()) }
}
