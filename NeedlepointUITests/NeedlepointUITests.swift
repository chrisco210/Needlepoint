import XCTest

/// Drives the app shell. Every launch passes `-ui-testing` so the app uses an
/// empty in-memory store instead of whatever is saved in the simulator.
final class ShellUITests: XCTestCase {
    private let tabLabels = ["Patterns", "WIP", "Ready", "Stash", "Shopping"]

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

    @MainActor
    private func open(_ label: String, in app: XCUIApplication) {
        let button = app.buttons[label].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 5), "No tab button named \(label)")
        button.tap()
        XCTAssertTrue(button.isSelected, "Couldn't select the \(label) tab")
    }

    /// The iPad tab bar sits at the top of the screen. When the labels don't
    /// fit, it scrolls behind a "Next Page" arrow and hides tabs off screen.
    @MainActor
    func testEveryTabFitsInTheTabBar() {
        let app = launch()
        XCTAssertTrue(app.buttons["Patterns"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Next Page"].exists, "The tab bar overflows")
        for label in tabLabels {
            XCTAssertTrue(app.buttons[label].firstMatch.isHittable, "\(label) isn't visible in the tab bar")
        }
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
            "Ready": "No patterns yet",
            "Stash": "No threads in your stash yet",
            "Shopping": "Nothing to buy",
        ]
        for label in tabLabels {
            open(label, in: app)
            XCTAssertTrue(
                app.staticTexts[emptyTitles[label]!].waitForExistence(timeout: 5),
                "\(label) didn't show its empty state")
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
