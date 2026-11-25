import XCTest

/// Drives the app shell.
final class ShellUITests: XCTestCase {
    private let tabLabels = ["Patterns", "WIP", "Ready", "Stash", "Shopping"]

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// The iPad tab bar sits at the top of the screen. When the labels don't
    /// fit, it scrolls behind a "Next Page" arrow and hides tabs off screen.
    @MainActor
    func testEveryTabFitsInTheTabBar() {
        let app = XCUIApplication.launchForTesting()
        XCTAssertTrue(app.buttons["Patterns"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Next Page"].exists, "The tab bar overflows")
        for label in tabLabels {
            XCTAssertTrue(app.buttons[label].firstMatch.isHittable, "\(label) isn't visible in the tab bar")
        }
    }

    @MainActor
    func testAppStartsOnPatternsWithTheSummaryBand() {
        let app = XCUIApplication.launchForTesting()
        XCTAssertTrue(app.staticTexts["Stitch Stash"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Your pattern library is empty"].exists)
        XCTAssertEqual(app.staticTexts["summary.patterns"].label, "0 patterns")
        XCTAssertEqual(app.staticTexts["summary.threadsOnHand"].label, "0 threads on hand")
        XCTAssertEqual(app.staticTexts["summary.toBuy"].label, "0 to buy")
    }

    @MainActor
    func testEveryTabShowsItsEmptyState() {
        let app = XCUIApplication.launchForTesting()
        let emptyTitles = [
            "Patterns": "Your pattern library is empty",
            "WIP": "Nothing on the needle",
            "Ready": "No patterns yet",
            "Stash": "No threads in your stash yet",
            "Shopping": "Nothing to buy",
        ]
        for label in tabLabels {
            app.openTab(label)
            XCTAssertTrue(
                app.staticTexts[emptyTitles[label]!].waitForExistence(timeout: 5),
                "\(label) didn't show its empty state")
        }
    }

    @MainActor
    func testSeeWhatsReadySwitchesToTheReadyTab() {
        let app = XCUIApplication.launchForTesting()
        app.openTab("WIP")
        let button = app.buttons["See what's ready"]
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        button.tap()
        XCTAssertTrue(app.staticTexts["No patterns yet"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testThreadsOnHandSumsTheStash() {
        // The seed holds two threads with quantities 2 and 3.
        let app = XCUIApplication.launchForTesting(["-ui-testing-seed-stash"])
        let stat = app.staticTexts["summary.threadsOnHand"]
        XCTAssertTrue(stat.waitForExistence(timeout: 5))
        XCTAssertEqual(stat.label, "5 threads on hand")
    }
}
