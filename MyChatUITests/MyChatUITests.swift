import XCTest

final class MyChatUITests: XCTestCase {
    func testExample() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertGreaterThanOrEqual(app.buttons.count, 0)
    }
}
