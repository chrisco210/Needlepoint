import XCTest

/// The Patterns tab. `-ui-testing-seed-patterns` adds:
/// - Strawberry by "Kirk & Bradley", Stitching, 13 mesh, needs DMC Floss 310 and 321
/// - Lemon by "kirk & bradley", Not started, no threads
/// - Mystery Santa with no designer, Wishlist, notes "Gift for Mom", needs Silk & Ivory 01
final class PatternsUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func launchSeeded(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication.launchForTesting(["-ui-testing-seed-patterns"] + extra)
        XCTAssertTrue(app.staticTexts["Stitch Stash"].waitForExistence(timeout: 5))
        return app
    }

    @MainActor
    private func folderTiles(in app: XCUIApplication) -> XCUIElementQuery {
        app.descendants(matching: .any).matching(identifier: "folderTile")
    }

    @MainActor
    private func patternCards(in app: XCUIApplication) -> XCUIElementQuery {
        app.descendants(matching: .any).matching(identifier: "patternCard")
    }

    @MainActor
    private func labels(of query: XCUIElementQuery) -> [String] {
        query.allElementsBoundByIndex.map(\.label)
    }

    @MainActor
    func testSummaryAndBadgeCountPatterns() {
        let app = launchSeeded()
        XCTAssertEqual(app.staticTexts["summary.patterns"].label, "3 patterns")
        XCTAssertFalse(app.staticTexts["Your pattern library is empty"].exists)
    }

    @MainActor
    func testFoldersListDesignersWithNoDesignerLast() {
        let app = launchSeeded()
        XCTAssertTrue(folderTiles(in: app).firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(labels(of: folderTiles(in: app)), [
            "Kirk & Bradley, 2 patterns, 1 in progress",
            "No designer, 1 pattern",
        ])
    }

    @MainActor
    func testStatusFilterShowsMatchCountsAndHidesEmptyFolders() {
        let app = launchSeeded()
        app.buttons["patterns.statusFilter"].tap()
        app.buttons["Stitching"].tap()
        XCTAssertEqual(labels(of: folderTiles(in: app)), ["Kirk & Bradley, 1 of 2 patterns, 1 in progress"])
    }

    @MainActor
    func testAllPatternsListsCardsInStandardOrder() {
        let app = launchSeeded(["-ui-testing-seed-stash"])
        app.buttons["All patterns"].tap()
        XCTAssertTrue(patternCards(in: app).firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(labels(of: patternCards(in: app)), [
            "Strawberry, Kirk & Bradley, 13 mesh, Stitching, 1 of 2 threads in stash",
            "Lemon, kirk & bradley, Not started, No threads listed",
            "Mystery Santa, Designer not set, Wishlist, 1 of 1 threads in stash",
        ])
    }

    @MainActor
    func testOpeningAFolderShowsItsPatterns() {
        let app = launchSeeded()
        folderTiles(in: app).firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Kirk & Bradley"].waitForExistence(timeout: 5))
        XCTAssertEqual(patternCards(in: app).count, 2)
    }

    @MainActor
    func testSearchInFoldersModeSearchesEveryFolder() {
        let app = launchSeeded()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("gift")
        XCTAssertTrue(app.staticTexts["Showing matches from every folder."].waitForExistence(timeout: 5))
        XCTAssertEqual(patternCards(in: app).count, 1)
        XCTAssertEqual(folderTiles(in: app).count, 0)
    }

    @MainActor
    func testSearchWithNoMatchesSaysSo() {
        let app = launchSeeded()
        app.buttons["All patterns"].tap()
        let search = app.searchFields.firstMatch
        search.tap()
        search.typeText("zzz")
        XCTAssertTrue(app.staticTexts["No patterns match that search."].waitForExistence(timeout: 5))
    }
}
