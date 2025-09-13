import XCTest
@testable import NoteChat

final class MathRenderingTests: XCTestCase {
    func testMathWebViewStoresLatex() {
        let view = MathWebView(latex: "x^2")
        XCTAssertEqual(view.latex, "x^2")
    }
}
