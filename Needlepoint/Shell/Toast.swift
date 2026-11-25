import SwiftUI

/// Short success messages ("Pattern saved", "Thread removed") shown over the
/// app for about two seconds. Views get it from the environment.
@Observable
final class ToastCenter {
    private(set) var message: String?
    private var dismissal: Task<Void, Never>?

    func show(_ message: String) {
        self.message = message
        dismissal?.cancel()
        dismissal = Task {
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            self.message = nil
        }
    }
}

private struct ToastOverlay: ViewModifier {
    let center: ToastCenter
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let message = center.message {
                    Text(message)
                        .font(.appBody(16, relativeTo: .callout).weight(.bold))
                        .foregroundStyle(Color.background)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(Color.ink, in: Capsule())
                        .padding(.bottom, 20)
                        .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                        .accessibilityAddTraits(.isStaticText)
                        .allowsHitTesting(false)
                }
            }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: center.message)
            .onChange(of: center.message) { _, message in
                if let message {
                    AccessibilityNotification.Announcement(message).post()
                }
            }
    }
}

extension View {
    func toastOverlay(_ center: ToastCenter) -> some View {
        modifier(ToastOverlay(center: center))
    }
}
