import XCTest

/// Renaming a folder and editing its image. The seed has a "Kirk & Bradley"
/// folder with Strawberry and Lemon, and a "No designer" folder with Mystery Santa.
final class FolderUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func openFolder(at index: Int) -> XCUIApplication {
        let app = XCUIApplication.launchForTesting(["-ui-testing-seed-patterns"])
        let tile = app.descendants(matching: .any).matching(identifier: "folderTile").element(boundBy: index)
        XCTAssertTrue(tile.waitForExistence(timeout: 5))
        tile.tap()
        return app
    }

    /// Rename folder and Edit folder image live in the "Folder options" menu.
    @MainActor
    private func chooseFolderOption(_ title: String, in app: XCUIApplication) {
        let options = app.buttons["Folder options"]
        XCTAssertTrue(options.waitForExistence(timeout: 5))
        options.tap()
        let item = app.buttons[title]
        XCTAssertTrue(item.waitForExistence(timeout: 5), "No \(title) in the folder menu")
        item.tap()
    }

    @MainActor
    func testRenamingAFolderRenamesItsDesigner() {
        let app = openFolder(at: 0)
        chooseFolderOption("Rename folder", in: app)
        // SwiftUI doesn't pass an identifier to a text field inside an alert.
        let field = app.alerts.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.replaceText(with: "K&B Designs")
        app.alerts.buttons["Rename"].tap()

        XCTAssertTrue(app.staticTexts["Folder renamed"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.navigationBars["K&B Designs"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "patternCard").count, 2)

        app.navigationBars.buttons.element(boundBy: 0).tap()
        let tile = app.descendants(matching: .any).matching(identifier: "folderTile").firstMatch
        XCTAssertTrue(tile.waitForExistence(timeout: 5))
        XCTAssertEqual(tile.label, "K&B Designs, 2 patterns, 1 in progress")
    }

    @MainActor
    func testNoDesignerCannotBeRenamed() {
        let app = openFolder(at: 1)
        XCTAssertTrue(app.navigationBars["No designer"].waitForExistence(timeout: 5))
        app.buttons["Folder options"].tap()
        XCTAssertTrue(app.buttons["Edit folder image"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Rename folder"].exists)
    }

    @MainActor
    func testEditingTheFolderImageSavesTheBackground() {
        let app = openFolder(at: 0)
        chooseFolderOption("Edit folder image", in: app)
        XCTAssertTrue(app.navigationBars["Folder image"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Show whole image (best for logos)"].exists)
        XCTAssertTrue(app.buttons["Fill the tile"].exists)

        // The swatches are in the last section, below the fold.
        let plum = app.buttons["Plum"]
        plum.swipeUpUntilHittable(in: app)
        plum.tap()
        XCTAssertTrue(plum.isSelected)
        app.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts["Folder image saved"].waitForExistence(timeout: 5))
    }
}
