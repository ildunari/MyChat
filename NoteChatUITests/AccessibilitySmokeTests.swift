import XCTest

final class AccessibilitySmokeTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testSettingsRootHasKeyEntriesAccessible() {
        let app = XCUIApplication()
        app.launch()

        // Navigate to Settings tab if present; otherwise open Settings from handle if implemented
        if app.buttons["Settings"].waitForExistence(timeout: 3) {
            app.buttons["Settings"].tap()
        } else if app.buttons["Open Settings"].waitForExistence(timeout: 3) {
            app.buttons["Open Settings"].tap()
        }

        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))

        // Verify key rows exist and are hittable
        let keys = ["Providers", "Default Chat", "Appearance", "Personalization"]
        for key in keys {
            let cell = app.staticTexts[key]
            XCTAssertTrue(cell.waitForExistence(timeout: 3), "Missing row \(key)")
            XCTAssertTrue(cell.isHittable, "Row not accessible: \(key)")
        }
    }
}

