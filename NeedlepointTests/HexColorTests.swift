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
