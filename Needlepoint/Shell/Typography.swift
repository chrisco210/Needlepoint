import SwiftUI

/// Fonts from the web app. Until the font files are bundled and listed under
/// `UIAppFonts`, `Font.custom` falls back to the system font. Both scale with
/// Dynamic Type through `relativeTo`.
extension Font {
    static func heading(_ size: CGFloat, relativeTo style: Font.TextStyle = .title) -> Font {
        .custom("DMSerifDisplay-Regular", size: size, relativeTo: style)
    }

    static func appBody(_ size: CGFloat = 17, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom("NunitoSans-Regular", size: size, relativeTo: style)
    }
}
