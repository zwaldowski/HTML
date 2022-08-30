//
//  HTMLAttributedStringTests.swift
//  HTMLTests
//
//  Created by Zachary Waldowski on 9/17/19.
//

import HTML
import XCTest

func assertNumberOfRanges(_ numberOfRanges: Int, for attribute: NSAttributedString.Key, in text: NSAttributedString, file: StaticString = #file, line: UInt = #line) {
    var count = 0
    text.enumerateAttribute(attribute, in: NSRange(0 ..< text.length)) { (_, _, _) in
        count += 1
    }
    XCTAssertEqual(count, numberOfRanges, file: file, line: line)
}

class HTMLAttributedStringTests: XCTestCase {
    func testHTMLParses() {
        let text = HTML.attributedString(from: """
            <b>Hello, <br /><br /><i>world</i>!</b><br />
        """)

        XCTAssertEqual(text.string, """
            Hello,\u{0020}

            world!

            """)
        assertNumberOfRanges(4, for: .font, in: text)
    }

    func testThatEntitiesParse() {
        let text = HTML.attributedString(from: """
            <b>Hello,&nbsp;<br /><br /><i>world</i>!</b><br />
        """)

        XCTAssertEqual(text.string, """
            Hello,\u{0020}

            world!

            """)
        assertNumberOfRanges(4, for: .font, in: text)
    }
    
    func testThatCommentsAreIgnored() {
        let text = HTML.attributedString(from: """
            <p>Super. Computer.</p><!-- Blah blah blah. -->
        """)
        
        XCTAssertEqual(text.string, """
            Super. Computer.
            """)
        assertNumberOfRanges(1, for: .font, in: text)
    }

    func testClearlyBrokenHTMLParses() {
        let text = HTML.attributedString(from: """
            <b>Hello, <BR><BR><I>world</b></i>!<br />
        """)

        XCTAssertEqual(text.string, """
            Hello,\u{0020}

            world!

            """)
        assertNumberOfRanges(3, for: .font, in: text)
    }

    func testThatUnsupportedTagsAreIgnored() {
        let text = HTML.attributedString(from: """
            <b>Hello, <br /><br /><i><font face="Times New Roman">world</font></i>!</b><br />
        """)

        XCTAssertEqual(text.string, """
            Hello,\u{0020}

            world!

            """)
        assertNumberOfRanges(4, for: .font, in: text)
    }

    func testThatLinksAreParsed() {
        let text = HTML.attributedString(from: """
            Super. Computer. <a href="http://www.apple.com/ipad-pro/" title="iPad Pro">Now in two sizes.</a>
        """)

        XCTAssertEqual(text.string, """
            Super. Computer. Now in two sizes.
            """)
        assertNumberOfRanges(1, for: .font, in: text)
        assertNumberOfRanges(2, for: .link, in: text)
    }

    func testThatInvalidLinksAreNotParsed() {
        let text = HTML.attributedString(from: """
            Super. Computer. <a>Now in two sizes.</a>
        """)

        XCTAssertEqual(text.string, """
            Super. Computer. Now in two sizes.
            """)
        assertNumberOfRanges(1, for: .font, in: text)
        assertNumberOfRanges(1, for: .link, in: text)
    }

    func testLists() {
        let orderedList = HTML.attributedString(from: """
            <ol><li>a</li><li>b</li></ol>
        """)

        XCTAssertEqual(orderedList.string, """
            1. a
            2. b

            """)

        let numberedList = HTML.attributedString(from: """
            <ol start="5"><li>a\n</li>\n<li>b</li></ol>
        """)

        XCTAssertEqual(numberedList.string, """
            5. a
            6. b

            """)

        let unorderedList = HTML.attributedString(from: """
            <ul><li>a</li><li>b</li></ul>
        """)

        XCTAssertEqual(unorderedList.string, """
            • a
            • b

            """)
    }
   
    func testListItemsNotInAList() {
        let noOpenerList = HTML.attributedString(from: """
            <li>one</li>
            <li>two</li>
            <li>three</li>
            </ol>
        """)

        XCTAssertEqual(noOpenerList.string, """
            one
            two
            three

            """)
    }

    func testListItemsWithoutClosingTags() {
        let brokeList = HTML.attributedString(from: """
            <ol>
            <li>ol without closing tags
            <li>item 2
            <li>item 3
            </ol>
        """)

        XCTAssertEqual(brokeList.string, """
            1. ol without closing tags
            2. item 2
            3. item 3

            """)
    }

    func testInsignificantNewlines() {
        let implicitRootNode = HTML.attributedString(from: """
            (91) 1800 4250 744\n\n09:00 to 21:00 (Monday through Friday)<br />\n10:00 to 18:00 (Saturday)
        """)

        XCTAssertEqual(implicitRootNode.string, """
            (91) 1800 4250 744 09:00 to 21:00 (Monday through Friday)
             10:00 to 18:00 (Saturday)
            """)

        let explicitRootNode = HTML.attributedString(from: """
            <p>(91) 1800 4250 744\n\n09:00 to 21:00 (Monday through Friday)<br />\n10:00 to 18:00 (Saturday)</p>
        """)

        XCTAssertEqual(explicitRootNode.string, """
            (91) 1800 4250 744 09:00 to 21:00 (Monday through Friday)
             10:00 to 18:00 (Saturday)
            """)
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
            _ = HTML.attributedString(from: self.speedTest)
        }
    }
}
