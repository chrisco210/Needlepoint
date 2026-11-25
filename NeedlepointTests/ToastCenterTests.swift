import Testing
@testable import Needlepoint

/// These use a short duration so the suite doesn't wait the real two seconds.
/// The margins are wide because the waits run on a shared simulator.
@MainActor
struct ToastCenterTests {
    @Test func defaultDurationIsAboutTwoSeconds() {
        #expect(ToastCenter().duration == .seconds(2))
    }

    @Test func showSetsTheMessage() {
        let toasts = ToastCenter(duration: .seconds(5))
        toasts.show("Thread removed")
        #expect(toasts.message == "Thread removed")
    }

    @Test func messageClearsAfterTheDuration() async throws {
        let toasts = ToastCenter(duration: .milliseconds(200))
        toasts.show("Pattern saved")
        try await Task.sleep(for: .milliseconds(600))
        #expect(toasts.message == nil)
    }

    @Test func aNewMessageReplacesTheOldOneAndRestartsTheTimer() async throws {
        let toasts = ToastCenter(duration: .milliseconds(500))
        toasts.show("First")
        try await Task.sleep(for: .milliseconds(300))
        toasts.show("Second")
        // 600 ms after "First" and 300 ms after "Second": the first timer
        // would have cleared it by now, the restarted one hasn't.
        try await Task.sleep(for: .milliseconds(300))
        #expect(toasts.message == "Second")
        try await Task.sleep(for: .milliseconds(600))
        #expect(toasts.message == nil)
    }
}
