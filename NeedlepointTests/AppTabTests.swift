import Testing
@testable import Needlepoint

struct AppTabTests {
    @Test func tabLabelsAreShortAndInReadmeOrder() {
        #expect(AppTab.allCases.map(\.tabLabel) == ["Patterns", "WIP", "Ready", "Stash", "Shopping"])
    }

    @Test func screenTitlesUseTheFullNames() {
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
