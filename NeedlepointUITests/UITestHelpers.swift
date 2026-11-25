import XCTest

extension XCUIApplication {
    /// Launches with `-ui-testing`, which gives the app an empty in-memory
    /// store instead of whatever is saved in the simulator.
    @MainActor
    static func launchForTesting(_ extraArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"] + extraArguments
        app.launch()
        return app
    }

    @MainActor
    func openTab(_ label: String, file: StaticString = #filePath, line: UInt = #line) {
        let button = buttons[label].firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 5), "No tab button named \(label)", file: file, line: line)
        button.tap()
        XCTAssertTrue(button.isSelected, "Couldn't select the \(label) tab", file: file, line: line)
    }
}
