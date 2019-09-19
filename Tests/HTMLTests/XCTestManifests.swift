import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(HTMLAttributedStringTests.allTests),
        testCase(HTMLDocumentTests.allTests),
    ]
}
#endif
