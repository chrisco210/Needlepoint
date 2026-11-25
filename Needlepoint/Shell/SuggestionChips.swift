import SwiftUI

/// A scrolling row of suggestions under a text field. Tapping one calls `onPick`.
struct SuggestionChips: View {
    let suggestions: [String]
    let onPick: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(suggestions, id: \.self) { suggestion in
                    Button(suggestion) { onPick(suggestion) }
                        .buttonStyle(.bordered)
                        .tint(Color.plum)
                }
            }
        }
        .frame(minHeight: 44)
    }
}
