import Testing
@testable import Needlepoint

struct HexColorTests {
    @Test(arguments: ["#7a1f4f", "7a1f4f", "#7A1F4F", "  #7a1f4f "])
    func parsesSixDigitHex(input: String) throws {
        let color = try #require(HexColor(input))
        #expect(color.string == "#7a1f4f")
        #expect(abs(color.red - 0x7a / 255) < 0.0001)
        #expect(abs(color.green - 0x1f / 255) < 0.0001)
        #expect(abs(color.blue - 0x4f / 255) < 0.0001)
    }

    @Test(arguments: ["", "#", "#fff", "#12345", "#1234567", "#gggggg", "red"])
    func rejectsAnythingElse(input: String) {
        #expect(HexColor(input) == nil)
    }

    @Test func formatsComponentsAsLowercaseHex() {
        #expect(HexColor(red: 1, green: 0, blue: 0.5).string == "#ff0080")
    }

    @Test func clampsComponentsOutsideZeroToOne() {
        // Wide-gamut colors from ColorPicker can fall outside 0...1 in sRGB.
        #expect(HexColor(red: 1.2, green: -0.1, blue: 0).string == "#ff0000")
    }

    @Test func roundTripsThroughComponents() throws {
        let original = try #require(HexColor("#0c7480"))
        #expect(HexColor(red: original.red, green: original.green, blue: original.blue) == original)
    }
}

struct HexColorContrastTests {
    @Test func blackOnWhiteIsTwentyOneToOne() throws {
        let black = try #require(HexColor("#000000"))
        let white = try #require(HexColor("#ffffff"))
        #expect(abs(black.contrastRatio(with: white) - 21) < 0.01)
        #expect(abs(white.contrastRatio(with: black) - 21) < 0.01)
    }

    @Test func aColorHasNoContrastWithItself() throws {
        let plum = try #require(HexColor("#7a1f4f"))
        #expect(abs(plum.contrastRatio(with: plum) - 1) < 0.0001)
    }

    /// WCAG gives #777777 on white about 4.48 to 1.
    @Test func matchesTheWCAGFormula() throws {
        let gray = try #require(HexColor("#777777"))
        let white = try #require(HexColor("#ffffff"))
        #expect(abs(gray.contrastRatio(with: white) - 4.48) < 0.01)
    }

    @Test(arguments: ["#7a1f4f", "#221b26", "#000000", "#0c7480"])
    func darkColors(hex: String) throws {
        #expect(try #require(HexColor(hex)).isDark)
    }

    @Test(arguments: ["#ffffff", "#f6e4ec", "#fbf3e2", "#e3eef6", "#cccccc"])
    func lightColors(hex: String) throws {
        #expect(try !#require(HexColor(hex)).isDark)
    }
}
