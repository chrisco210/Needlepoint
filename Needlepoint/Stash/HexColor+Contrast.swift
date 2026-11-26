import Foundation

nonisolated extension HexColor {
    /// WCAG relative luminance, from 0 for black to 1 for white.
    var luminance: Double {
        func linear(_ c: Double) -> Double {
            c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    /// WCAG contrast ratio, from 1 to 21. Text needs 4.5 and large glyphs 3.
    func contrastRatio(with other: HexColor) -> Double {
        let (lighter, darker) = luminance > other.luminance ? (self, other) : (other, self)
        return (lighter.luminance + 0.05) / (darker.luminance + 0.05)
    }

    /// True when white shows better on this color than black.
    var isDark: Bool {
        contrastRatio(with: HexColor(red: 1, green: 1, blue: 1))
            > contrastRatio(with: HexColor(red: 0, green: 0, blue: 0))
    }
}
