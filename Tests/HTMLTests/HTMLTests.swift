import XCTest
@testable import HTML

final class HTMLTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(HTML().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
