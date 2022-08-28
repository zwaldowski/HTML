//
//  HTMLTests.swift
//  HTMLTests
//
//  Created by Zachary Waldowski on 4/23/19.
//

import HTML
import XCTest

class HTMLTests: XCTestCase {
    func loadFixture() throws -> HTML.Node {
        return try HTML.parse(xml_dot_html)
    }

    func testDoesNotParseEmptyString() throws {
        XCTAssertThrowsError(try HTML.parse(""))
    }

    func testDoesNotParseInvalidTag() throws {
        XCTAssertThrowsError(try HTML.parse("<"))
    }

    func testParsesTextFragment() throws {
        let fragment = try HTML.parse("Lorem ipsum dolor amet")

        XCTAssertEqual(fragment.name, "html")
        XCTAssertEqual(fragment.kind, .element)
        XCTAssertEqual(fragment.content, "Lorem ipsum dolor amet")
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
        XCTAssertEqual(try HTML.parse("<html />").isEmpty, true)
    }

    func testCollectionCount() throws {
        let html = try loadFixture()
        XCTAssertEqual(html.count, 5)
        XCTAssertEqual(html.dropFirst().first?.count, 53)
        XCTAssertEqual(try HTML.parse("<html />").count, 0)
    }

    func testCollectionFirst() throws {
        let html = try loadFixture()
        let head = html.dropFirst().first
        XCTAssertNotNil(head)
        XCTAssertEqual(head?.name, "head")
        XCTAssertEqual(head?.kind, .element)

        let title = head?.dropFirst(3).first
        XCTAssertEqual(title?.name, "title")
        XCTAssertEqual(title?.kind, .element)
        XCTAssertEqual(title?.content, "XML - Wikipedia")

        XCTAssertNil(head?.first?.first)

        let body = html.dropFirst(3).first
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
        let fragment = try HTML.parse("<img />")
        XCTAssertEqual(fragment.content, "")
    }

    func testDebugDescription() throws {
        let html = try loadFixture()
        let description = String(reflecting: html)
        XCTAssert(description.hasPrefix("<html"))
        XCTAssert(description.hasSuffix("</html>"))

        let fragment = try HTML.parse("Lorem ipsum dolor amet")
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