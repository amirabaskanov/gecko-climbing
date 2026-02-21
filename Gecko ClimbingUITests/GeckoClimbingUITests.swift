import XCTest

final class GeckoClimbingUITests: XCTestCase {
    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launch()
    }

    func testExample() throws {
        XCTAssertTrue(app.exists)
    }
}
