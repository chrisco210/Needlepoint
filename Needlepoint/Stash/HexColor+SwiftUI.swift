import SwiftUI

extension Color {
    init(_ hex: HexColor) {
        self.init(.sRGB, red: hex.red, green: hex.green, blue: hex.blue)
    }

    /// The swatch for a stored `#rrggbb` string, or the unknown-color gray if
    /// the string doesn't parse.
    init(swatch: String) {
        self.init(HexColor(swatch) ?? HexColor(StashThread.unknownColor)!)
    }
}

extension HexColor {
    init(_ color: Color) {
        let resolved = color.resolve(in: EnvironmentValues())
        self.init(red: Double(resolved.red), green: Double(resolved.green), blue: Double(resolved.blue))
    }
}
