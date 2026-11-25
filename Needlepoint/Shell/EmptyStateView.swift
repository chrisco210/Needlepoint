import SwiftUI

/// The centered heading, explanation and optional buttons a tab shows when it
/// has nothing to list.
struct EmptyStateView<Actions: View>: View {
    let title: String
    let message: String
    @ViewBuilder var actions: Actions

    var body: some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.heading(28, relativeTo: .title))
                .foregroundStyle(Color.ink)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            Text(message)
                .font(.appBody())
                .foregroundStyle(Color.mute)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 460)
            actions
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.top, 8)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 48)
        .frame(maxWidth: .infinity)
    }
}

extension EmptyStateView where Actions == EmptyView {
    init(title: String, message: String) {
        self.init(title: title, message: message) { EmptyView() }
    }
}
