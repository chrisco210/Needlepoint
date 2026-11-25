import XCTest

/// The pattern editor sheet. See `PatternsUITests` for the seeded patterns.
final class PatternEditorUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func type(_ text: String, into element: XCUIElement) {
        element.tap()
        element.typeText(text)
    }

    @MainActor
    private func field(_ identifier: String, in app: XCUIApplication, index: Int = 0) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).element(boundBy: index)
    }

    @MainActor
    private func patternCard(named name: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'patternCard' AND label BEGINSWITH %@", name + ","))
            .firstMatch
    }

    @MainActor
    func testAddingAPatternFromTheEmptyStateCreatesItsFolder() {
        let app = XCUIApplication.launchForTesting()
        app.buttons["Add pattern"].firstMatch.tap()
        let name = field("patternEditor.name", in: app)
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        type("Strawberry", into: name)
        type("Kirk & Bradley", into: field("patternEditor.designer", in: app))
        app.buttons["Save"].tap()

        XCTAssertTrue(app.staticTexts["Pattern saved"].waitForExistence(timeout: 5))
        let tile = app.descendants(matching: .any).matching(identifier: "folderTile").firstMatch
        XCTAssertTrue(tile.waitForExistence(timeout: 5))
        XCTAssertEqual(tile.label, "Kirk & Bradley, 1 pattern")
    }

    @MainActor
    func testSaveIsDisabledUntilThePatternHasAName() {
        let app = XCUIApplication.launchForTesting()
        app.buttons["Add pattern"].firstMatch.tap()
        let name = field("patternEditor.name", in: app)
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Save"].isEnabled)
        type("Strawberry", into: name)
        XCTAssertTrue(app.buttons["Save"].isEnabled)
    }

    @MainActor
    func testThreadRowsShowStashStatusAndReuseTheBrand() {
        // The seeded stash has 2 of DMC Floss 310 and none of 321.
        let app = XCUIApplication.launchForTesting(["-ui-testing-seed-stash"])
        app.buttons["Add pattern"].firstMatch.tap()
        XCTAssertTrue(field("patternEditor.name", in: app).waitForExistence(timeout: 5))

        app.buttons["patternEditor.addThread"].tap()
        type("DMC Floss", into: field("threadRow.brand", in: app))
        type("310", into: field("threadRow.code", in: app))
        XCTAssertEqual(field("threadRow.status", in: app).label, "In stash (2)")

        app.buttons["patternEditor.addThread"].tap()
        XCTAssertEqual(field("threadRow.brand", in: app, index: 1).value as? String, "DMC Floss")
        // The new row's number field has focus, so typing goes straight into it.
        app.typeText("321")
        XCTAssertEqual(field("threadRow.status", in: app, index: 1).label, "Need 1 more")
    }

    @MainActor
    func testTappingACardOpensItInTheEditor() {
        let app = XCUIApplication.launchForTesting(["-ui-testing-seed-patterns"])
        app.buttons["All patterns"].tap()
        patternCard(named: "Strawberry", in: app).tap()

        let name = field("patternEditor.name", in: app)
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        XCTAssertEqual(name.value as? String, "Strawberry")
        // Strawberry's PDF preview pushes the thread rows below the fold, and
        // Form only creates rows that are on screen.
        app.buttons["patternEditor.addThread"].swipeUpUntilHittable(in: app)
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "threadRow.code").count, 2)
        XCTAssertTrue(app.navigationBars["Edit pattern"].exists)
    }

    @MainActor
    func testDeletingAPatternAsksFirst() {
        let app = XCUIApplication.launchForTesting(["-ui-testing-seed-patterns"])
        app.buttons["All patterns"].tap()
        patternCard(named: "Lemon", in: app).tap()

        let delete = app.buttons["Delete pattern"]
        XCTAssertTrue(delete.waitForExistence(timeout: 5))
        delete.tap()
        XCTAssertTrue(app.staticTexts["Delete \"Lemon\"?"].waitForExistence(timeout: 5))
        app.buttons["Delete"].tap()

        XCTAssertTrue(app.staticTexts["Pattern deleted"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "patternCard").count, 2)
        XCTAssertFalse(patternCard(named: "Lemon", in: app).exists)
    }

    @MainActor
    func testNewPatternsHaveNoDeleteButton() {
        let app = XCUIApplication.launchForTesting()
        app.buttons["Add pattern"].firstMatch.tap()
        XCTAssertTrue(field("patternEditor.name", in: app).waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Delete pattern"].exists)
    }

    @MainActor
    func testAddToThisFolderPrefillsTheDesigner() {
        let app = XCUIApplication.launchForTesting(["-ui-testing-seed-patterns"])
        app.descendants(matching: .any).matching(identifier: "folderTile").firstMatch.tap()
        let add = app.buttons["Add to this folder"]
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()
        let designer = field("patternEditor.designer", in: app)
        XCTAssertTrue(designer.waitForExistence(timeout: 5))
        XCTAssertEqual(designer.value as? String, "Kirk & Bradley")
    }

    @MainActor
    func testCancelLeavesThePatternUnchanged() {
        let app = XCUIApplication.launchForTesting(["-ui-testing-seed-patterns"])
        app.buttons["All patterns"].tap()
        patternCard(named: "Lemon", in: app).tap()
        let name = field("patternEditor.name", in: app)
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText(" Tart")
        app.buttons["Cancel"].tap()
        XCTAssertTrue(patternCard(named: "Lemon", in: app).waitForExistence(timeout: 5))
    }
}
