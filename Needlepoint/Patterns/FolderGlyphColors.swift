import Foundation

/// Colors for what a folder tile draws on its background. Folder backgrounds
/// are fixed colors that don't change with dark mode, so these follow the
/// background, not the appearance.
nonisolated struct FolderGlyphColors {
    /// The folder glyph.
    let glyph: HexColor
    /// The designer's initial, printed on the glyph.
    let initial: HexColor
    /// "No image" in the folder image editor's preview.
    let label: HexColor

    private static let plum = HexColor(red: 0x7a / 255, green: 0x1f / 255, blue: 0x4f / 255)
    private static let lightPlum = HexColor(red: 0xe7 / 255, green: 0x9a / 255, blue: 0xc4 / 255)
    private static let mute = HexColor(red: 0x6d / 255, green: 0x63 / 255, blue: 0x72 / 255)

    init(background: HexColor) {
        glyph = background.isDark ? Self.lightPlum : Self.plum
        initial = background
        label = background.isDark ? HexColor(red: 1, green: 1, blue: 1) : Self.mute
    }
}
