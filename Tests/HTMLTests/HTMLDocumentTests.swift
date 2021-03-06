//
//  HTMLDocumentTests.swift
//  HTMLTests
//
//  Created by Zachary Waldowski on 4/23/19.
//

import XCTest
import HTML

class HTMLDocumentTests: XCTestCase {
    
    static let allTests = [
        ("testAttributes", testAttributes),
        ("testCollectionCount", testCollectionCount),
        ("testCollectionFirst", testCollectionFirst),
        ("testCollectionIsEmpty", testCollectionIsEmpty),
        ("testContentForEmptyElement", testContentForEmptyElement),
        ("testDebugDescription", testDebugDescription),
        ("testDocumentReflection", testDocumentReflection),
        ("testDoesNotParseEmptyString", testDoesNotParseEmptyString),
        ("testDoesNotParseFragmentEmptyString", testDoesNotParseFragmentEmptyString),
        ("testDoesNotParseFragmentInvalidTag", testDoesNotParseFragmentInvalidTag),
        ("testDoesNotParseInvalidTag", testDoesNotParseInvalidTag),
        ("testKind", testKind),
        ("testName", testName),
        ("testParsesEscapedFragmentEmptyText", testParsesEscapedFragmentEmptyText),
        ("testParsesEscapedFragmentWithMultipleNodes", testParsesEscapedFragmentWithMultipleNodes),
        ("testParsesEscapedFragmentWithOneNode", testParsesEscapedFragmentWithOneNode),
        ("testParsesTextFragment", testParsesTextFragment),
        ("testReflection", testReflection),
    ]
    
    func loadFixture() throws -> HTMLDocument.Node {
        return try HTMLDocument.parse(xml_dot_html)
    }

    func testDoesNotParseEmptyString() throws {
        XCTAssertThrowsError(try HTMLDocument.parse(""))
    }

    func testDoesNotParseFragmentEmptyString() throws {
        XCTAssertThrowsError(try HTMLDocument.parseFragment(""))
    }

    func testDoesNotParseInvalidTag() throws {
        XCTAssertThrowsError(try HTMLDocument.parse("<"))
    }

    func testDoesNotParseFragmentInvalidTag() throws {
        XCTAssertThrowsError(try HTMLDocument.parseFragment("&lt;"))
    }

    func testParsesTextFragment() throws {
        let fragment = try HTMLDocument.parse("Lorem ipsum dolor amet")

        XCTAssertEqual(fragment.name, "html")
        XCTAssertEqual(fragment.kind, .element)
        XCTAssertEqual(fragment.content, "Lorem ipsum dolor amet")
    }

    func testParsesEscapedFragmentEmptyText() throws {
        let fragment = try HTMLDocument.parseFragment("&lt;p&gt;Less than character: 4 &lt; 5, 5 &gt; 3&lt;/p&gt;")

        XCTAssertEqual(fragment.name, "p")
        XCTAssertEqual(fragment.kind, .element)
        XCTAssertEqual(fragment.content, "Less than character: 4 < 5, 5 > 3")
    }

    func testParsesEscapedFragmentWithOneNode() throws {
        let fragment = try HTMLDocument.parseFragment("&lt;p&gt;Less than character: 4 &lt; 5, 5 &gt; 3&lt;/p&gt;")

        XCTAssertEqual(fragment.name, "p")
        XCTAssertEqual(fragment.kind, .element)
        XCTAssertEqual(fragment.content, "Less than character: 4 < 5, 5 > 3")
    }

    func testParsesEscapedFragmentWithMultipleNodes() throws {
        let fragment = try HTMLDocument.parseFragment("&lt;p&gt;Less than character: 4 &lt; 5, 5 &gt; 3&lt;/p&gt;&lt;p&gt;And another paragraph.&lt;/p&gt;")

        XCTAssertEqual(fragment.kind, .documentFragment)

        let paragraph1 = fragment.first
        XCTAssertNotNil(paragraph1)
        XCTAssertEqual(paragraph1?.name, "p")
        XCTAssertEqual(paragraph1?.kind, .element)
        XCTAssertEqual(paragraph1?.content, "Less than character: 4 < 5, 5 > 3")

        let paragraph2 = fragment.dropFirst().first
        XCTAssertNotNil(paragraph2)
        XCTAssertEqual(paragraph2?.name, "p")
        XCTAssertEqual(paragraph2?.kind, .element)
        XCTAssertEqual(paragraph2?.content, "And another paragraph.")

        XCTAssertNil(fragment.dropFirst(2).first)
    }

    func testName() throws {
        let html = try loadFixture()
        XCTAssertEqual(html.name, "html")
    }

    func testKind() throws {
        let html = try loadFixture()
        XCTAssertEqual(html.kind, .element)
    }

    func testCollectionIsEmpty() throws {
        let html = try loadFixture()
        XCTAssertFalse(html.isEmpty)
        XCTAssertEqual(try HTMLDocument.parse("<html />").isEmpty, true)
    }

    func testCollectionCount() throws {
        let html = try loadFixture()
        XCTAssertEqual(html.count, 2)
        XCTAssertEqual(html.first?.count, 26)
        XCTAssertEqual(try HTMLDocument.parse("<html />").count, 0)
    }

    func testCollectionFirst() throws {
        let html = try loadFixture()
        let head = html.first
        XCTAssertNotNil(head)
        XCTAssertEqual(head?.name, "head")
        XCTAssertEqual(head?.kind, .element)

        let title = head?.dropFirst().first
        XCTAssertEqual(title?.name, "title")
        XCTAssertEqual(title?.kind, .element)
        XCTAssertEqual(title?.content, "XML - Wikipedia")

        XCTAssertNil(head?.first?.first)

        let body = html.dropFirst().first
        XCTAssertNotNil(body)
        XCTAssertEqual(body?.name, "body")
        XCTAssertEqual(body?.kind, .element)

        let scriptContents = body?.dropFirst(11).first?.first
        XCTAssertEqual(scriptContents?.name, "")
        XCTAssertEqual(scriptContents?.kind, .characterDataSection)
        XCTAssertEqual(scriptContents?.content.isEmpty, false)

        let footer = body?.dropFirst(9).first
        XCTAssertEqual(footer?.name, "div")
        XCTAssertEqual(footer?.kind, .element)
        XCTAssertEqual(footer?.content.isEmpty, false)
        XCTAssertEqual(footer?["id"], "footer")

        XCTAssertNil(footer?.dropFirst(5).first?.first)
    }

    func testAttributes() throws {
        let html = try loadFixture()
        XCTAssertEqual(html["class"], "client-nojs")
        XCTAssertEqual(html["lang"], "en")
        XCTAssertEqual(html["dir"], "ltr")
        XCTAssertNil(html[""])
        XCTAssertNil(html["data:does-not-exist"])
    }

    func testContentForEmptyElement() throws {
        let fragment = try HTMLDocument.parse("<img />")
        XCTAssertEqual(fragment.content, "")
    }

    func testDebugDescription() throws {
        let html = try loadFixture()
        let description = String(reflecting: html)
        XCTAssert(description.hasPrefix("<html"))
        XCTAssert(description.hasSuffix("</html>"))

        let fragment = try HTMLDocument.parse("Lorem ipsum dolor amet")
        let fragmentDescription = String(reflecting: fragment)
        XCTAssertEqual(fragmentDescription, "<html><body><p>Lorem ipsum dolor amet</p></body></html>")
    }

    func testReflection() throws {
        let html = try loadFixture()
        let magicMirror = Mirror(reflecting: html)
        XCTAssertEqual(magicMirror.displayStyle, .struct)
        XCTAssertNil(magicMirror.superclassMirror)
        XCTAssertNil(magicMirror.descendant(0, 0, 2, 0))
    }

    func testDocumentReflection() throws {
        let html = try loadFixture()
        let magicMirror = Mirror(reflecting: html.document)
        XCTAssertEqual(magicMirror.displayStyle, .class)
        XCTAssertNil(magicMirror.superclassMirror)
        XCTAssertNil(magicMirror.descendant(0, 0, 2, 0))
    }

}
