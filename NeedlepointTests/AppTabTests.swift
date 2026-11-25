import Testing
@testable import Needlepoint

struct AppTabTests {
    @Test func tabsAreInReadmeOrderWithReadmeTitles() {
        #expect(AppTab.allCases.map(\.title) == [
            "Patterns", "WIP", "Ready to stitch", "Thread stash", "Shopping list",
        ])
    }

    @Test func everyTabHasAnIcon() {
        for tab in AppTab.allCases {
            #expect(!tab.systemImage.isEmpty, "\(tab) has no icon")
        }
    }
}
