import XCTest

/// The WIP, Ready to stitch and Shopping list tabs. With both seeds:
/// - Strawberry (Stitching) needs DMC Floss 310, which the stash has, and 321, which it doesn't
/// - Lemon (Not started) lists no threads
/// - Mystery Santa (Wishlist) needs Silk & Ivory 01, which the stash has
final class LibraryTabsUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func launch(stash: Bool = true) -> XCUIApplication {
        XCUIApplication.launchForTesting(["-ui-testing-seed-patterns"] + (stash ? ["-ui-testing-seed-stash"] : []))
    }

    @MainActor
    private func cards(in app: XCUIApplication) -> XCUIElementQuery {
        app.descendants(matching: .any).matching(identifier: "patternCard")
    }

    @MainActor
    private func cardNames(in app: XCUIApplication) -> [String] {
        cards(in: app).allElementsBoundByIndex.map { String($0.label.prefix { $0 != "," }) }
    }

    // MARK: - WIP

    @MainActor
    func testWIPListsStitchingPatternsWithWhatTheyStillNeed() {
        let app = launch()
        app.openTab("WIP")
        XCTAssertTrue(app.staticTexts["On the needle"].waitForExistence(timeout: 5))
        XCTAssertEqual(cardNames(in: app), ["Strawberry"])
        XCTAssertTrue(app.staticTexts["DMC Floss 321 Red: need 1"].exists)
    }

    @MainActor
    func testWIPButtonsMoveAPatternThroughFinishing() {
        let app = launch()
        app.openTab("WIP")
        app.buttons["Done stitching"].tap()
        XCTAssertTrue(app.staticTexts["\"Strawberry\" is stitched, on to finishing"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Stitched, needs finishing"].exists)

        app.buttons["Back to stitching"].tap()
        XCTAssertTrue(app.staticTexts["\"Strawberry\" is on the needle"].waitForExistence(timeout: 5))

        app.buttons["Done stitching"].tap()
        let finish = app.buttons["Mark finished"]
        XCTAssertTrue(finish.waitForExistence(timeout: 5))
        finish.tap()
        XCTAssertTrue(app.staticTexts["\"Strawberry\" marked finished, congrats!"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Nothing on the needle"].waitForExistence(timeout: 5))
    }

    // MARK: - Ready to stitch

    @MainActor
    func testReadyShowsReadyAndAlmostThereWithAFootnote() {
        let app = launch()
        app.openTab("Ready")
        XCTAssertTrue(app.staticTexts["Almost there"].waitForExistence(timeout: 5))
        XCTAssertEqual(cardNames(in: app), ["Mystery Santa", "Strawberry"])
        XCTAssertTrue(app.staticTexts["DMC Floss 321 Red: need 1"].exists)
        XCTAssertTrue(app.staticTexts[
            "1 pattern has no threads listed yet, so it isn't counted here. Open it and add the threads."
        ].exists)
    }

    @MainActor
    func testStartStitchingPutsAPatternOnTheNeedle() {
        let app = launch()
        app.openTab("Ready")
        let start = app.buttons["Start stitching"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        start.tap()
        XCTAssertTrue(app.staticTexts["\"Mystery Santa\" is on the needle"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Already on the needle"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testTurningOffWishlistHidesWishlistPatterns() {
        let app = launch()
        app.openTab("Ready")
        let toggle = app.switches["ready.includeWishlist"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        toggle.switches.firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Nothing is fully covered by your stash yet. See what's close below."]
            .waitForExistence(timeout: 5))
        XCTAssertEqual(cardNames(in: app), ["Strawberry"])
    }

    // MARK: - Shopping list

    @MainActor
    func testShoppingListShowsWhatToBuy() {
        let app = launch(stash: false)
        app.openTab("Shopping")
        let rows = app.descendants(matching: .any).matching(identifier: "shoppingRow")
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(rows.allElementsBoundByIndex.map(\.label), [
            "310, Black, Buy 1, need 1, have 0, for Strawberry",
            "321, Red, Buy 1, need 1, have 0, for Strawberry",
        ])
        XCTAssertTrue(app.staticTexts["DMC Floss"].exists)

        app.openTab("Patterns")
        XCTAssertEqual(app.staticTexts["summary.toBuy"].label, "2 to buy")
    }

    @MainActor
    func testBoughtItAddsToTheStashAndEmptiesTheList() {
        let app = launch()
        app.openTab("Shopping")
        let bought = app.buttons["Bought it"]
        XCTAssertTrue(bought.waitForExistence(timeout: 5))
        bought.tap()
        XCTAssertTrue(app.staticTexts["DMC Floss 321 added to stash"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Your stash covers every active pattern."].waitForExistence(timeout: 5))

        app.openTab("Stash")
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "stashRow")["321, Red, 1 on hand"]
            .waitForExistence(timeout: 5))
    }

    @MainActor
    func testIncludingWishlistAddsWishlistThreads() {
        let app = launch(stash: false)
        app.openTab("Shopping")
        let toggle = app.switches["shopping.includeWishlist"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        toggle.switches.firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Silk & Ivory"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testCopyListShowsAToast() {
        let app = launch(stash: false)
        app.openTab("Shopping")
        let copy = app.buttons["Copy list"]
        XCTAssertTrue(copy.waitForExistence(timeout: 5))
        copy.tap()
        XCTAssertTrue(app.staticTexts["Shopping list copied"].waitForExistence(timeout: 5))
    }
}
