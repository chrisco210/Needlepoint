import XCTest

/// Searching, editing, removing and pasting in the Stash tab. The seed holds
/// DMC Floss 310 Black (2) and Silk & Ivory 01 Snow (3).
final class StashEditingUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func launchOnStash() -> XCUIApplication {
        let app = XCUIApplication.launchForTesting(["-ui-testing-seed-stash"])
        app.openTab("Stash")
        XCTAssertTrue(rows(in: app).firstMatch.waitForExistence(timeout: 5))
        return app
    }

    @MainActor
    private func rows(in app: XCUIApplication) -> XCUIElementQuery {
        app.descendants(matching: .any).matching(identifier: "stashRow")
    }

    @MainActor
    private func row(_ label: String, in app: XCUIApplication) -> XCUIElement {
        rows(in: app).matching(NSPredicate(format: "label == %@", label)).firstMatch
    }

    @MainActor
    func testSearchFiltersByColorName() {
        let app = launchOnStash()
        let search = app.searchFields.firstMatch
        search.tap()
        search.typeText("snow")
        XCTAssertTrue(row("01, Snow, 3 on hand", in: app).waitForExistence(timeout: 5))
        XCTAssertEqual(rows(in: app).count, 1)
    }

    @MainActor
    func testStepperChangesTheQuantity() {
        let app = launchOnStash()
        app.buttons.matching(identifier: "stashRow.qty-Increment").firstMatch.tap()
        XCTAssertTrue(row("310, Black, 3 on hand", in: app).waitForExistence(timeout: 5))
    }

    @MainActor
    func testTappingARowEditsTheThread() {
        let app = launchOnStash()
        row("310, Black, 2 on hand", in: app).tap()
        XCTAssertTrue(app.navigationBars["Edit thread"].waitForExistence(timeout: 5))
        let name = app.textFields["threadEditor.name"]
        XCTAssertEqual(name.value as? String, "Black")
        name.tap()
        name.typeText(" Velvet")
        app.buttons["Save"].tap()

        XCTAssertTrue(app.staticTexts["Thread saved"].waitForExistence(timeout: 5))
        XCTAssertTrue(row("310, Black Velvet, 2 on hand", in: app).waitForExistence(timeout: 5))
    }

    @MainActor
    func testAnEditCannotDuplicateAnotherThread() {
        let app = launchOnStash()
        row("01, Snow, 3 on hand", in: app).tap()
        let brand = app.textFields["threadEditor.brand"]
        XCTAssertTrue(brand.waitForExistence(timeout: 5))
        brand.replaceText(with: "DMC Floss")
        app.textFields["threadEditor.code"].replaceText(with: "310")
        app.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts["That brand and number is already in your stash."].waitForExistence(timeout: 5))
    }

    @MainActor
    func testRemovingFromTheEditorAsksFirst() {
        let app = launchOnStash()
        row("01, Snow, 3 on hand", in: app).tap()
        let remove = app.buttons["Remove from stash"]
        XCTAssertTrue(remove.waitForExistence(timeout: 5))
        remove.tap()
        XCTAssertTrue(app.staticTexts["Remove Silk & Ivory 01?"].waitForExistence(timeout: 5))
        app.buttons["Remove"].tap()
        XCTAssertTrue(app.staticTexts["Thread removed"].waitForExistence(timeout: 5))
        XCTAssertEqual(rows(in: app).count, 1)
    }

    @MainActor
    func testSwipingToRemoveAsksFirst() {
        let app = launchOnStash()
        row("01, Snow, 3 on hand", in: app).swipeLeft()
        app.buttons["Remove"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Remove Silk & Ivory 01?"].waitForExistence(timeout: 5))
        app.buttons["Remove"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Thread removed"].waitForExistence(timeout: 5))
        XCTAssertEqual(rows(in: app).count, 1)
    }

    @MainActor
    func testPastingAListAddsThreads() {
        let app = launchOnStash()
        app.buttons["Paste a list"].firstMatch.tap()
        let text = app.textViews["pasteList.text"]
        XCTAssertTrue(text.waitForExistence(timeout: 5))
        text.tap()
        text.typeText("DMC Floss, 310, 2\nKreinik #12 Braid, 002, Gold")
        app.buttons["Add threads"].tap()

        XCTAssertTrue(app.staticTexts["Added 2 threads"].waitForExistence(timeout: 5))
        XCTAssertTrue(row("310, Black, 4 on hand", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(row("002, Gold, 1 on hand", in: app).exists)
    }

    @MainActor
    func testEmptyStashOffersPasteAList() {
        let app = XCUIApplication.launchForTesting()
        app.openTab("Stash")
        XCTAssertEqual(app.buttons.matching(identifier: "Paste a list").count, 2,
                       "Expected Paste a list in the toolbar and the empty state")
    }
}

extension XCUIElement {
    /// Replaces a text field's contents. Tapping near the right edge puts the
    /// cursor after the text, so deleting once per character clears it.
    @MainActor
    func replaceText(with text: String) {
        coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.5)).tap()
        let current = (value as? String) ?? ""
        typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
        typeText(text)
    }
}
