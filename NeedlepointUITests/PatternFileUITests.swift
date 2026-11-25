import XCTest

/// The pattern file and cover sections of the editor. The seed gives
/// Strawberry a one-page PDF; Lemon has no file.
final class PatternFileUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func openPattern(_ name: String, extraArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication.launchForTesting(["-ui-testing-seed-patterns"] + extraArguments)
        app.buttons["All patterns"].tap()
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'patternCard' AND label BEGINSWITH %@", name + ","))
            .firstMatch
            .tap()
        XCTAssertTrue(app.descendants(matching: .any)["patternEditor.name"].waitForExistence(timeout: 5))
        return app
    }

    @MainActor
    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    @MainActor
    func testAPDFPatternShowsItsPreviewAndFileName() {
        let app = openPattern("Strawberry")
        XCTAssertTrue(element("patternEditor.pdfPreview", in: app).exists)
        XCTAssertTrue(app.staticTexts["strawberry.pdf"].exists)
        XCTAssertTrue(app.buttons["Replace file"].exists)
    }

    @MainActor
    func testUsingPageOneOfThePDFSetsTheCover() {
        let app = openPattern("Strawberry")
        XCTAssertFalse(element("patternEditor.coverPreview", in: app).exists)
        let usePageOne = app.buttons["Use page 1 of the PDF"]
        usePageOne.firstMatch.swipeUpUntilHittable(in: app)
        usePageOne.tap()
        XCTAssertTrue(element("patternEditor.coverPreview", in: app).waitForExistence(timeout: 5))
        // The new preview pushes the button below the fold, and Form only
        // creates rows that are on screen.
        let removeCover = app.buttons["Remove cover"]
        removeCover.swipeUpUntilHittable(in: app)
        XCTAssertTrue(removeCover.exists)
    }

    /// `-ui-testing-fake-camera` stands in for the system camera, which UI
    /// tests can't drive: "Take a photo" returns a generated photo at once.
    @MainActor
    func testTakingAPhotoSetsTheCover() {
        let app = XCUIApplication.launchForTesting(["-ui-testing-seed-patterns", "-ui-testing-fake-camera"])
        app.buttons["All patterns"].tap()
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier == 'patternCard' AND label BEGINSWITH %@", "Lemon,"))
            .firstMatch
            .tap()
        let takePhoto = app.buttons["Take a photo"]
        takePhoto.swipeUpUntilHittable(in: app)
        takePhoto.tap()
        XCTAssertTrue(element("patternEditor.coverPreview", in: app).waitForExistence(timeout: 5))
    }

    /// Some simulators report a camera, so `-ui-testing-no-camera` stands in
    /// for a device without one.
    @MainActor
    func testTakeAPhotoIsHiddenWithoutACamera() {
        let app = openPattern("Lemon", extraArguments: ["-ui-testing-no-camera"])
        app.buttons["Choose a photo"].swipeUpUntilHittable(in: app)
        XCTAssertTrue(app.buttons["Choose a photo"].exists)
        XCTAssertFalse(app.buttons["Take a photo"].exists)
    }

    @MainActor
    func testAPatternWithoutAFileOffersToAttachOne() {
        let app = openPattern("Lemon")
        XCTAssertTrue(app.buttons["Attach file"].exists)
        XCTAssertTrue(app.staticTexts["No file yet"].exists)
        XCTAssertFalse(app.buttons["Use page 1 of the PDF"].exists)
        XCTAssertFalse(element("patternEditor.pdfPreview", in: app).exists)
    }

    @MainActor
    func testOpeningThePDFFullScreenAndClosingIt() {
        let app = openPattern("Strawberry")
        app.buttons["Open PDF full screen"].tap()
        let done = app.buttons["Done"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        XCTAssertTrue(element("patternViewer.pdf", in: app).exists)
        done.tap()
        XCTAssertTrue(element("patternEditor.name", in: app).waitForExistence(timeout: 5))
    }
}

extension XCUIElement {
    /// Scrolls the form until this element can be tapped.
    @MainActor
    func swipeUpUntilHittable(in app: XCUIApplication, maxSwipes: Int = 5) {
        var swipes = 0
        while !(exists && isHittable) && swipes < maxSwipes {
            app.swipeUp()
            swipes += 1
        }
    }
}
