import XCTest

/// The Add thread editor and the stash list it feeds.
final class StashUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func openEditor(in app: XCUIApplication) -> XCUIElement {
        app.openTab("Stash")
        app.buttons["Add thread"].firstMatch.tap()
        let brand = app.textFields["threadEditor.brand"]
        XCTAssertTrue(brand.waitForExistence(timeout: 5), "The Add thread editor didn't open")
        return brand
    }

    @MainActor
    private func type(_ text: String, into identifier: String, in app: XCUIApplication) {
        let field = app.textFields[identifier]
        field.tap()
        field.typeText(text)
    }

    @MainActor
    private func stashRows(in app: XCUIApplication) -> XCUIElementQuery {
        app.descendants(matching: .any).matching(identifier: "stashRow")
    }

    @MainActor
    func testAddingAThreadShowsItInTheStash() {
        let app = XCUIApplication.launchForTesting()
        _ = openEditor(in: app)
        type("DMC Floss", into: "threadEditor.brand", in: app)
        type("310", into: "threadEditor.code", in: app)
        type("Black", into: "threadEditor.name", in: app)
        // SwiftUI names a stepper's buttons after its identifier.
        app.buttons["threadEditor.qty-Increment"].tap()
        app.buttons["Save"].tap()

        XCTAssertTrue(app.staticTexts["Thread saved"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["No threads in your stash yet"].exists)
        XCTAssertEqual(stashRows(in: app).count, 1)
        XCTAssertEqual(stashRows(in: app).firstMatch.label, "310, Black, 2 on hand")
        XCTAssertTrue(app.staticTexts["DMC Floss"].exists, "No section header for the brand")

        app.openTab("Patterns")
        XCTAssertEqual(app.staticTexts["summary.threadsOnHand"].label, "2 threads on hand")
    }

    @MainActor
    func testSaveIsDisabledUntilBrandAndCodeAreFilled() {
        let app = XCUIApplication.launchForTesting()
        _ = openEditor(in: app)
        let save = app.buttons["Save"]
        XCTAssertFalse(save.isEnabled)
        type("DMC Floss", into: "threadEditor.brand", in: app)
        XCTAssertFalse(save.isEnabled)
        type("310", into: "threadEditor.code", in: app)
        XCTAssertTrue(save.isEnabled)
    }

    @MainActor
    func testCancelAddsNothing() {
        let app = XCUIApplication.launchForTesting()
        _ = openEditor(in: app)
        type("DMC Floss", into: "threadEditor.brand", in: app)
        type("310", into: "threadEditor.code", in: app)
        app.buttons["Cancel"].tap()

        XCTAssertTrue(app.staticTexts["No threads in your stash yet"].waitForExistence(timeout: 5))
        XCTAssertEqual(stashRows(in: app).count, 0)
    }

    @MainActor
    func testAddingAThreadAlreadyInTheStashUpdatesIt() {
        // The seed holds DMC Floss 310 and Silk & Ivory 01.
        let app = XCUIApplication.launchForTesting(["-ui-testing-seed-stash"])
        _ = openEditor(in: app)
        type("dmc floss", into: "threadEditor.brand", in: app)
        type("310", into: "threadEditor.code", in: app)
        type("Noir", into: "threadEditor.name", in: app)
        app.buttons["Save"].tap()

        XCTAssertTrue(app.staticTexts["Already in stash, updated it"].waitForExistence(timeout: 5))
        XCTAssertEqual(stashRows(in: app).count, 2)
        XCTAssertTrue(stashRows(in: app)["310, Noir, 1 on hand"].exists)
    }

    @MainActor
    func testTappingABrandSuggestionFillsTheField() {
        let app = XCUIApplication.launchForTesting()
        let brand = openEditor(in: app)
        type("neon", into: "threadEditor.brand", in: app)
        let suggestion = app.buttons["Rainbow Gallery Neon Rays"]
        XCTAssertTrue(suggestion.waitForExistence(timeout: 5))
        suggestion.tap()
        XCTAssertEqual(brand.value as? String, "Rainbow Gallery Neon Rays")
    }

    @MainActor
    func testEmptyStateAndToolbarBothOpenTheEditor() {
        let app = XCUIApplication.launchForTesting()
        app.openTab("Stash")
        let addButtons = app.buttons.matching(identifier: "Add thread")
        XCTAssertTrue(addButtons.firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(addButtons.count, 2, "Expected an Add thread button in the toolbar and the empty state")
    }
}
