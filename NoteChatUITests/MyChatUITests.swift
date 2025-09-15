import XCTest

final class MyChatUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testSettingsDockOpensOnTap() {
        let app = XCUIApplication()
        app.launch()

        let dockButton = app.buttons["Open Settings"]
        XCTAssertTrue(dockButton.waitForExistence(timeout: 5), "Settings dock button not found")
        dockButton.tap()

        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 5), "Settings sheet did not appear")

        // Dismiss
        app.buttons["Done"].tap()
    }

    func testPersonalizationUpdatesDockTitle() {
        let app = XCUIApplication()
        app.launch()

        // Open settings
        let dockButton = app.buttons["Open Settings"]
        XCTAssertTrue(dockButton.waitForExistence(timeout: 5))
        dockButton.tap()
        XCTAssertTrue(app.staticTexts["Settings"].waitForExistence(timeout: 5))

        // Navigate to Personalization (may need a scroll on smaller heights)
        if !app.staticTexts["Personalization"].isHittable {
            app.swipeUp()
        }
        app.staticTexts["Personalization"].tap()

        // Update Username to a known value
        let username = "UITUser"
        let usernameField = app.textFields["Username"]
        XCTAssertTrue(usernameField.waitForExistence(timeout: 5))
        usernameField.tap()
        clear(textField: usernameField)
        usernameField.typeText(username)

        // Navigate back to Settings root and dismiss
        if app.navigationBars.buttons.element(boundBy: 0).exists {
            app.navigationBars.buttons.element(boundBy: 0).tap()
        }
        app.buttons["Done"].tap()

        // Verify dock title reflects username
        XCTAssertTrue(app.staticTexts[username].waitForExistence(timeout: 5), "Dock title did not update to username")
    }
}

// MARK: - Helpers
private func clear(textField: XCUIElement) {
    // Attempt to clear by selecting all and deleting; fall back to sending deletes.
    textField.press(forDuration: 0.8)
    let selectAll = XCUIApplication().menuItems["Select All"]
    if selectAll.waitForExistence(timeout: 1) {
        selectAll.tap()
        textField.typeText(XCUIKeyboardKey.delete.rawValue)
    } else {
        // Send a handful of deletes just in case
        for _ in 0..<10 { textField.typeText(XCUIKeyboardKey.delete.rawValue) }
    }
}
