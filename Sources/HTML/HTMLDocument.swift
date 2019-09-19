//
//  HTMLDocument.swift
//  HTML
//
//  Created by Zachary Waldowski on 2/19/19.
//

import CHTML

/// A fragment of HTML parsed into a logical tree structure. A tree can have
/// many child nodes but only one element, the root element.
public final class HTMLDocument {
    
    /// An error caused by the inability to parse malformed HTML.
    public struct ParseError: Error, CustomDebugStringConvertible {
        public let code: Int
        public let debugDescription: String
    }

    /// Element nodes in an tree structure. An element may have child nodes,
    /// specifically element nodes, text nodes, comment nodes, or
    /// processing-instruction nodes. It may also have subscript attributes.
    public struct Node {
        /// The different element types carried by an XML tree.
        /// See http://www.w3.org/TR/REC-DOM-Level-1/
        public typealias Kind = xmlElementType

        public struct Index {
            let variant: IndexVariant
        }

        /// A strong back-reference to the containing document.
        public let document: HTMLDocument
        
        let handle: htmlNodePtr
    }

    let handle: htmlDocPtr

    init<Input>(parsing input: Input) throws where Input: StringProtocol {
        let options = Int32(bitPattern:
            HTML_PARSE_RECOVER.rawValue |
            HTML_PARSE_NOERROR.rawValue |
            HTML_PARSE_NOWARNING.rawValue |
            HTML_PARSE_NONET.rawValue |
            HTML_PARSE_NOBLANKS.rawValue)

        guard let handle = input.withCString({ (cString) in
            htmlReadMemory(cString, Int32(strlen(cString)), nil, "UTF-8", options)
        }) else { throw ParseError.lastError }

        self.handle = handle
    }

    deinit {
        xmlFreeDoc(self.handle)
    }

}

extension HTMLDocument {

    /// Parses the HTML contents of a string source, such as "<p>Hello.</p>"
    public static func parse<Input>(_ input: Input) throws -> Node where Input: StringProtocol {
        let document = try HTMLDocument(parsing: input)
        guard let root = document.root else { throw ParseError.lastError }
        return root
    }

    /// Parses the HTML contents of an escaped string source, such as "&lt;p&gt;Hello.&lt;/p&gt;".
    public static func parseFragment<Input>(_ input: Input) throws -> Node where Input: StringProtocol {
        guard let temporaryTextNode = try self.parse("<html><body>\(input)").first?.first,
            temporaryTextNode.kind == .text,
            let body = try self.parse("<html><body>\(temporaryTextNode.content)").first,
            let firstChild = body.first else { throw ParseError.lastError }
        
        if !body.dropFirst().isEmpty, let fragment = xmlNewDocFragment(body.document.handle) {
            // If the fragment is many elements (such as
            // `<p>Foo.</p><p>Bar.</p>`), transplant them into a fragment node
            // instead of returning the fake `<root>` element to protect against
            // a parser not understanding that element.
            for child in body {
                xmlUnlinkNode(child.handle)
                xmlAddChild(fragment, child.handle)
            }
            return Node(document: body.document, handle: fragment)
        }

        // Otherwise, if the fragment is one and only one element (such as a
        // lone `<p></p>`), simply return that node.
        return firstChild
    }

    /// The root node of the receiver.
    public var root: Node? {
        guard let rootHandle = xmlDocGetRootElement(self.handle) else { return nil }
        return Node(document: self, handle: rootHandle)
    }

}

// MARK: - Node

extension HTMLDocument.Node {

    /// The natural type of this element.
    /// See also [the W3C](http://www.w3.org/TR/REC-DOM-Level-1/).
    public var kind: Kind {
        return self.handle.pointee.type
    }

    /// The element tag. (ex: for `<foo />`, `"foo"`)
    public var name: String {
        guard let pointer = self.handle.pointee.name else { return "" }
        return String(cString: pointer)
    }

    /// If the node is a text node, the text carried directly by the node.
    /// Otherwise, the aggregrate string of the values carried by this node.
    public var content: String {
        guard let buffer = xmlNodeGetContent(self.handle) else { return "" }
        defer { xmlFree(buffer) }
        return String(cString: buffer)
    }

    /// Request the content of the attribute `key`.
    public subscript(key: String) -> String? {
        guard let buffer = xmlGetProp(self.handle, key) else { return nil }
        defer { xmlFree(buffer) }
        return String(cString: buffer)
    }

}

extension HTMLDocument.Node: Collection {

    enum IndexVariant: Equatable {
        case valid(htmlNodePtr, offset: Int)
        case invalid
    }

    public var startIndex: Index {
        guard let firstHandle = self.handle.pointee.children else { return Index(variant: .invalid) }
        return Index(variant: .valid(firstHandle, offset: 0))
    }

    public var endIndex: Index {
        return Index(variant: .invalid)
    }

    public subscript(position: Index) -> HTMLDocument.Node {
        guard case .valid(let handle, _) = position.variant else { preconditionFailure("Index out of bounds") }
        return HTMLDocument.Node(document: self.document, handle: handle)
    }

    public func index(after position: Index) -> Index {
        guard case .valid(let handle, let offset) = position.variant,
            let nextHandle = handle.pointee.next else { return Index(variant: .invalid) }
        let nextOffset = offset + 1
        return Index(variant: .valid(nextHandle, offset: nextOffset))
    }

}

extension HTMLDocument.Node: CustomDebugStringConvertible {

    public var debugDescription: String {
        let buffer = xmlBufferCreate()
        defer { xmlBufferFree(buffer) }

        htmlNodeDump(buffer, self.document.handle, self.handle)
        return String(cString: xmlBufferContent(buffer))
    }

}

extension HTMLDocument.Node: CustomReflectable {

    public var customMirror: Mirror {
        // Always use the debugDescription for `po`, none of this "▿" stuff.
        return Mirror(self, unlabeledChildren: self, displayStyle: .struct)
    }

}

// MARK: - Node Kind

extension HTMLDocument.Node.Kind {

    /// Specifies an element node.
    public static let element = XML_ELEMENT_NODE
    /// Specifies a text node.
    public static let text = XML_TEXT_NODE
    /// Specifies textual data within a node.
    public static let characterDataSection = XML_CDATA_SECTION_NODE
    /// Specifies a subset of a document.
    public static let documentFragment = XML_DOCUMENT_FRAG_NODE

}

// MARK: - Node Index

extension HTMLDocument.Node.Index: Comparable {

    public static func == (lhs: HTMLDocument.Node.Index, rhs: HTMLDocument.Node.Index) -> Bool {
        return lhs.variant == rhs.variant
    }

    public static func < (lhs: HTMLDocument.Node.Index, rhs: HTMLDocument.Node.Index) -> Bool {
        switch (lhs.variant, rhs.variant) {
        case (.valid(_, let lhs), .valid(_, let rhs)):
            return lhs < rhs
        case (.valid, .invalid):
            return true
        default:
            return false
        }
    }

}

// MARK: - Parse Errors

extension HTMLDocument.ParseError {
    
    static var lastError: Error {
        guard let error = xmlGetLastError() else {
            return HTMLDocument.ParseError(code: -1, debugDescription: "")
        }
        return HTMLDocument.ParseError(code: Int(error.pointee.code), debugDescription: String(cString: error.pointee.message))
    }
    
}
