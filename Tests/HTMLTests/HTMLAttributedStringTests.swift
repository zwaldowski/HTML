//
//  HTMLAttributedStringTests.swift
//  HTMLTests
//
//  Created by Zachary Waldowski on 9/17/19.
//

import XCTest
import HTML

func assertNumberOfLines(_ numberOfLines: Int, in text: NSAttributedString, file: StaticString = #file, line: UInt = #line) {
    let count = text.string.split(omittingEmptySubsequences: false) {
        $0.isNewline
    }.count
    XCTAssertEqual(count, numberOfLines, file: file, line: line)
}

func assertNumberOfRanges(_ numberOfRanges: Int, for attribute: NSAttributedString.Key, in text: NSAttributedString, file: StaticString = #file, line: UInt = #line) {
    var count = 0
    text.enumerateAttribute(attribute, in: NSRange(0 ..< text.length)) { (_, _, _) in
        count += 1
    }
    XCTAssertEqual(count, numberOfRanges, file: file, line: line)
}

class HTMLAttributedStringTests: XCTestCase {
    
    static let allTests = [
        ("testClearlyBrokenHTMLParses", testClearlyBrokenHTMLParses),
        ("testCustomParsingPerformance", testCustomParsingPerformance),
        ("testHTMLParses", testHTMLParses),
        ("testInsignificantNewlines", testInsignificantNewlines),
        ("testListItemsNotInAList", testListItemsNotInAList),
        ("testListItemsWithoutClosingTags", testListItemsWithoutClosingTags),
        ("testLists", testLists),
        ("testThatCommentsAreIgnored", testThatCommentsAreIgnored),
        ("testThatEntitiesParse", testThatEntitiesParse),
        ("testThatInvalidLinksAreNotParsed", testThatInvalidLinksAreNotParsed),
        ("testThatLinksAreParsed", testThatLinksAreParsed),
        ("testThatUnsupportedTagsAreIgnored", testThatUnsupportedTagsAreIgnored),
    ]

    func testHTMLParses() throws {
        let text = try HTMLDocument.parse("""
            <b>Hello, <br /><br /><i>world</i>!</b><br />
        """).attributedString()
        assertNumberOfLines(4, in: text)
        assertNumberOfRanges(4, for: .font, in: text)
    }

    func testThatEntitiesParse() throws {
        let text = try HTMLDocument.parse("""
            <b>Hello,&nbsp;<br /><br /><i>world</i>!</b><br />
        """).attributedString()

        assertNumberOfLines(4, in: text)
        assertNumberOfRanges(4, for: .font, in: text)
        XCTAssertNil(text.string.range(of: "&"))
    }
    
    func testThatCommentsAreIgnored() throws {
        let text = try HTMLDocument.parse("""
            <p>Super. Computer.</p><!-- Blah blah blah. -->
        """).attributedString()
        
        assertNumberOfLines(1, in: text)
        assertNumberOfRanges(1, for: .font, in: text)
        XCTAssertNil(text.string.range(of: "Blah blah blah."))
    }

    func testClearlyBrokenHTMLParses() throws {
        let text = try HTMLDocument.parse("""
            <b>Hello, <BR><BR><I>world</b></i>!<br />
        """).attributedString()

        assertNumberOfLines(4, in: text)
        assertNumberOfRanges(3, for: .font, in: text)
    }

    func testThatUnsupportedTagsAreIgnored() throws {
        let text = try HTMLDocument.parse("""
            <b>Hello, <br /><br /><i><font face="Times New Roman">world</font></i>!</b><br />
        """).attributedString()

        assertNumberOfLines(4, in: text)
        assertNumberOfRanges(4, for: .font, in: text)
    }

    func testThatLinksAreParsed() throws {
        let text = try HTMLDocument.parse("""
            Super. Computer. <a href="http://www.apple.com/ipad-pro/" title="iPad Pro">Now in two sizes.</a>
        """).attributedString()

        assertNumberOfLines(1, in: text)
        assertNumberOfRanges(1, for: .font, in: text)
        assertNumberOfRanges(2, for: .link, in: text)
    }

    func testThatInvalidLinksAreNotParsed() throws {
        let text = try HTMLDocument.parse("""
            Super. Computer. <a>Now in two sizes.</a>
        """).attributedString()

        assertNumberOfLines(1, in: text)
        assertNumberOfRanges(1, for: .font, in: text)
        assertNumberOfRanges(1, for: .link, in: text)
    }

    func testLists() throws {
        let orderedList = try HTMLDocument.parse("""
            <ol><li>a</li><li>b</li></ol>
        """).attributedString()

        assertNumberOfLines(3, in: orderedList)
        XCTAssertEqual(orderedList.string, "1. a\n2. b\n")

        let numberedList = try HTMLDocument.parse("""
            <ol start="5"><li>a\n</li>\n<li>b</li></ol>
        """).attributedString()

        assertNumberOfLines(3, in: numberedList)
        XCTAssertEqual(numberedList.string, "5. a\n6. b\n")

        let unorderedList = try HTMLDocument.parse("""
            <ul><li>a</li><li>b</li></ul>
        """).attributedString()

        assertNumberOfLines(3, in: unorderedList)
        XCTAssertEqual(unorderedList.string, "• a\n• b\n")
    }
   
    func testListItemsNotInAList() throws {
        let noOpenerList = try HTMLDocument.parse("""
            <li>one</li>
            <li>two</li>
            <li>three</li>
            </ol>
        """).attributedString()
        assertNumberOfLines(4, in: noOpenerList)
        XCTAssertEqual(noOpenerList.string, "one\ntwo\nthree\n")
    }

    func testListItemsWithoutClosingTags() throws {
        let brokeList = try HTMLDocument.parse("""
            <ol>
            <li>ol without closing tags
            <li>item 2
            <li>item 3
            </ol>
        """).attributedString()
        assertNumberOfLines(4, in: brokeList)
        XCTAssertEqual(brokeList.string, "1. ol without closing tags\n2. item 2\n3. item 3\n")
    }

    func testInsignificantNewlines() throws {
        let implicitRootNode = try HTMLDocument.parse("""
            (91) 1800 4250 744\n\n09:00 to 21:00 (Monday through Friday)<br />\n10:00 to 18:00 (Saturday)
        """).attributedString()

        assertNumberOfLines(2, in: implicitRootNode)

        let explicitRootNode = try HTMLDocument.parse("""
            <p>(91) 1800 4250 744\n\n09:00 to 21:00 (Monday through Friday)<br />\n10:00 to 18:00 (Saturday)</p>
        """).attributedString()

        assertNumberOfLines(2, in: explicitRootNode)
    }

    private let speedTest = """
        <b>Hello, <BR><BR><I>world</b></i>!<br />
    """

    #if canImport(AppKit) || canImport(UIKit)
    func testNativeParsingPerformance() {
        measure {
            let data = Data(self.speedTest.utf8)
            _ = try? NSMutableAttributedString(data: data, options: [
                .documentType: NSAttributedString.DocumentType.html,
                // `rawValue` needed due to <https://bugs.swift.org/browse/SR-3177>
                .characterEncoding : String.Encoding.utf8.rawValue
            ], documentAttributes: nil)
        }
    }
    #endif

    func testCustomParsingPerformance() {
        measure {
            _ = try? HTMLDocument.parse(self.speedTest)
                .attributedString()
        }
    }

}
