import Foundation
import Testing
import UIKit
@testable import Needlepoint

/// Checks the asset catalog colors against WCAG contrast in both appearances:
/// 4.5 to 1 for text, 3 to 1 for large glyphs.
@MainActor
struct ThemeColorTests {
    nonisolated enum Appearance: String, CaseIterable, CustomTestStringConvertible {
        case light, dark
        var testDescription: String { rawValue }
        var traits: UITraitCollection {
            UITraitCollection(userInterfaceStyle: self == .light ? .light : .dark)
        }
    }

    /// A text color and the background it sits on somewhere in the app.
    nonisolated struct Pair: CustomTestStringConvertible, Sendable {
        let text: String
        let background: String
        var testDescription: String { "\(text) on \(background)" }
    }

    nonisolated static let textPairs: [Pair] = [
        Pair(text: "Ink", background: "Background"),
        Pair(text: "Ink", background: "Card"),
        Pair(text: "Ink", background: "Blush"),
        Pair(text: "Mute", background: "Background"),
        Pair(text: "Mute", background: "Card"),
        Pair(text: "Mute", background: "Blush"),
        // Pattern card placeholders and suggestion chips.
        Pair(text: "Plum", background: "Blush"),
        Pair(text: "Plum", background: "Card"),
        Pair(text: "Plum", background: "Background"),
        Pair(text: "Warn", background: "Card"),
        Pair(text: "Warn", background: "Background"),
        Pair(text: "OK", background: "Card"),
        Pair(text: "AccentColor", background: "Card"),
        Pair(text: "AccentColor", background: "Background"),
        // The toast inverts the page colors.
        Pair(text: "Background", background: "Ink"),
        // The folder glyph's initial, printed on the glyph.
        Pair(text: "Blush", background: "Plum"),
        // The summary header, filled status pills, prominent buttons and the
        // Remove swipe action print white text.
        Pair(text: "White", background: "PlumFill"),
        Pair(text: "White", background: "AccentFill"),
        Pair(text: "White", background: "OKFill"),
        Pair(text: "White", background: "WarnFill"),
    ]

    static func color(_ name: String, _ appearance: Appearance) throws -> HexColor {
        if name == "White" { return HexColor(red: 1, green: 1, blue: 1) }
        let named = try #require(
            UIColor(named: name, in: Bundle(for: StashThread.self), compatibleWith: appearance.traits),
            "No color named \(name) in the asset catalog")
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        named.resolvedColor(with: appearance.traits).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return HexColor(red: red, green: green, blue: blue)
    }

    @Test(arguments: textPairs, Appearance.allCases)
    func textIsReadable(pair: Pair, appearance: Appearance) throws {
        let text = try Self.color(pair.text, appearance)
        let background = try Self.color(pair.background, appearance)
        #expect(text.contrastRatio(with: background) >= 4.5,
                "\(pair.text) \(text.string) on \(pair.background) \(background.string)")
    }

    /// The folder glyph on a tile with no folder style.
    @Test(arguments: Appearance.allCases)
    func folderGlyphShowsOnBlush(appearance: Appearance) throws {
        let glyph = try Self.color("Plum", appearance)
        let blush = try Self.color("Blush", appearance)
        #expect(glyph.contrastRatio(with: blush) >= 3)
    }

    /// Folder backgrounds are fixed colors, so the glyph on them can't follow
    /// the appearance. It has to suit the background instead.
    @Test(arguments: FolderImageDraft.backgrounds.map(\.hex))
    func folderGlyphShowsOnEveryFolderBackground(hex: String) throws {
        let background = try #require(HexColor(hex))
        let colors = FolderGlyphColors(background: background)
        #expect(colors.glyph.contrastRatio(with: background) >= 3)
        #expect(colors.initial.contrastRatio(with: colors.glyph) >= 4.5)
    }

    @Test(arguments: FolderImageDraft.backgrounds.map(\.hex))
    func noImageLabelShowsOnEveryFolderBackground(hex: String) throws {
        let background = try #require(HexColor(hex))
        #expect(FolderGlyphColors(background: background).label.contrastRatio(with: background) >= 4.5)
    }
}
