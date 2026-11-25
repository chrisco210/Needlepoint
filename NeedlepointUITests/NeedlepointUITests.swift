import XCTest

/// Drives the app shell. Every launch passes `-ui-testing` so the app uses an
/// empty in-memory store instead of whatever is saved in the simulator.
final class ShellUITests: XCTestCase {
    private let tabTitles = ["Patterns", "WIP", "Ready to stitch", "Thread stash", "Shopping list"]

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func launch(_ extraArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"] + extraArguments
        app.launch()
        return app
    }

    /// On an iPad in portrait the five titles don't fit in the top tab bar,
    /// which scrolls behind a "Next Page" arrow. Page forward until the tab
    /// is selected, the way a user would.
    @MainActor
    private func open(_ title: String, in app: XCUIApplication) {
        let button = app.buttons[title].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 5), "No tab button named \(title)")
        button.tap()
        let nextPage = app.buttons["Next Page"]
        var pages = 0
        while !button.isSelected, nextPage.exists, pages < 3 {
            nextPage.tap()
            button.tap()
            pages += 1
        }
        XCTAssertTrue(button.isSelected, "Couldn't select the \(title) tab")
    }

    @MainActor
    func testAppStartsOnPatternsWithTheSummaryBand() {
        let app = launch()
        XCTAssertTrue(app.staticTexts["Stitch Stash"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Your pattern library is empty"].exists)
        XCTAssertEqual(app.staticTexts["summary.patterns"].label, "0 patterns")
        XCTAssertEqual(app.staticTexts["summary.threadsOnHand"].label, "0 threads on hand")
        XCTAssertEqual(app.staticTexts["summary.toBuy"].label, "0 to buy")
    }

    @MainActor
    func testEveryTabShowsItsEmptyState() {
        let app = launch()
        let emptyTitles = [
            "Patterns": "Your pattern library is empty",
            "WIP": "Nothing on the needle",
            "Ready to stitch": "No patterns yet",
            "Thread stash": "No threads in your stash yet",
            "Shopping list": "Nothing to buy",
        ]
        for title in tabTitles {
            open(title, in: app)
            XCTAssertTrue(
                app.staticTexts[emptyTitles[title]!].waitForExistence(timeout: 5),
                "\(title) didn't show its empty state")
        }
    }

    @MainActor
    func testSeeWhatsReadySwitchesToTheReadyTab() {
        let app = launch()
        open("WIP", in: app)
        let button = app.buttons["See what's ready"]
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        button.tap()
        XCTAssertTrue(app.staticTexts["No patterns yet"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testThreadsOnHandSumsTheStash() {
        // The seed holds two threads with quantities 2 and 3.
        let app = launch(["-ui-testing-seed-stash"])
        let stat = app.staticTexts["summary.threadsOnHand"]
        XCTAssertTrue(stat.waitForExistence(timeout: 5))
        XCTAssertEqual(stat.label, "5 threads on hand")
    }
}
