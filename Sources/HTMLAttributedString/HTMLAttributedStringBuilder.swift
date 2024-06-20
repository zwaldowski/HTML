import libxml2
import SwiftUI

/// An object that incrementally creates an `AttributedString` from a fragment of HTML.
public final class HTMLAttributedStringBuilder {
    /// Options that affect the parsing of HTML content into an attributed string.
    public struct Options: Sendable {
        /// A type that represents the syntax for interpreting an HTML string.
        public enum InterpretedSyntax: Sendable {
            /// A syntax value that interprets all block and inline syntax.
            ///
            /// Use this mode when you want the complete `PresentationIntent` graph to use in a custom renderer.
            public static var full: Self {
                full(nil)
            }
            /// A syntax value that interprets all block and inline syntax, replacing blocks using a transformer object.
            ///
            /// Use this mode when you want to replace the `PresentationIntent` graph for use in another renderer, like TextKit.
            case full(PresentationIntentResolver?)
            /// A syntax value that parses all Markdown text, but interprets only attributes that apply to inline spans.
            ///
            /// Use this mode when you only need basic formatting, like bold, italic, or links.
            case inlineOnly
            /// A syntax value that parses all Markdown text, but interprets only attributes that apply to inline spans, preserving white space.
            ///
            /// Use this mode when you only need basic formatting, like bold, italic, or links; and the markup was authored with UI in mind, like a Foundation localized string.
            case inlineOnlyPreservingWhitespace
        }

        /// A type that transforms block elements in HTML.
        public struct PresentationIntentResolver: Sendable {
            var handler: @Sendable (AttributedSubstring, PresentationIntent?) -> AttributedString

            /// Creates a presentation intent resolver with the specified closure.
            public init(handler: @escaping @Sendable (AttributedSubstring, PresentationIntent?) -> AttributedString) {
                self.handler = handler
            }
        }

        /// A type that transforms `style=` attributes in HTML.
        public struct StyleResolver: Sendable {
            var handler: @Sendable (AttributeContainer, String, String) -> AttributeContainer

            /// Creates a style resolver with the specified closure.
            public init(handler: @escaping @Sendable (AttributeContainer, String, String) -> AttributeContainer) {
                self.handler = handler
            }
        }

        /// A type that transforms `img` tags in HTML.
        public struct ImageResolver: Sendable {
            var handler: @Sendable (AttributedSubstring, URL?) -> AttributedString?

            /// Creates an image resolver with the specified closure.
            public init(handler: @escaping @Sendable (AttributedSubstring, URL?) -> AttributedString?) {
                self.handler = handler
            }
        }

        /// A type that transforms `mark` tags in HTML.
        public struct MarkResolver: Sendable {
            var handler: @Sendable (AttributeContainer, Bool) -> AttributeContainer

            /// Creates a mark resolver with the specified closure.
            public init(handler: @escaping @Sendable (AttributeContainer, Bool) -> AttributeContainer) {
                self.handler = handler
            }
        }

        /// The syntax for interpreting an HTML string.
        public var interpretedSyntax: InterpretedSyntax
        /// How `style` properties on tags are resolved in the attributed string.
        public var style: StyleResolver?
        /// How `img` tags are resolved in the attributed string.
        public var image: ImageResolver?
        /// How `mark` tags are resolved in the attributed string.
        public var mark: MarkResolver?
        /// Indicates whether parsing allows `a` tags in HTML to become tappable hyperlinks.
        public var allowsLinks = true
    }

    enum Tag: String {
        case h1, h2, h3, h4, h5, h6
        case p, center
        case ol, ul, li
        case a
        case em, i
        case strong, b
        case br
        case img
        case mark, bl, lb
        case body
    }

    struct Context {
        var attributes = AttributeContainer()
        var shouldLeftTrimText = true
        var listOrdinal: Int?
    }

    let options: Options
    var result = AttributedString()
    var identity = 1
    var stack = [Context]()
    var current = Context()

    /// Creates the builder using the provided options.
    public init(options: Options) {
        self.options = options
    }

    /// Creates an attributed string from a HTML-formatted input.
    public func parse(_ input: String) -> AttributedString {
        var handler = htmlSAXHandler()
        handler.initialized = XML_SAX2_MAGIC
        handler.startElement = { context, name, attributes in
            let builder = Unmanaged<HTMLAttributedStringBuilder>.fromOpaque(context.unsafelyUnwrapped).takeUnretainedValue()
            let name = name.map(String.init)
            var attributes = attributes
            var properties = [String: String]()
            while let attribute = attributes, let key = attribute.pointee.map(String.init), let value = (attribute + 1).pointee.map(String.init) {
                properties[key] = value
                attributes = attribute + 2
            }
            builder.startElement(name: name, properties: properties)
        }
        handler.endElement = { context, name in
            let builder = Unmanaged<HTMLAttributedStringBuilder>.fromOpaque(context.unsafelyUnwrapped).takeUnretainedValue()
            let name = name.map(String.init)
            builder.endElement(name: name)
        }
        handler.characters = { context, start, count in
            let builder = Unmanaged<HTMLAttributedStringBuilder>.fromOpaque(context.unsafelyUnwrapped).takeUnretainedValue()
            let buffer = UnsafeBufferPointer(start: start, count: Int(count))
            let string = String(decoding: buffer, as: UTF8.self)
            builder.text(string)
        }

        let parser = htmlCreatePushParserCtxt(&handler, Unmanaged.passUnretained(self).toOpaque(), nil, 0, nil, XML_CHAR_ENCODING_UTF8)
        htmlCtxtUseOptions(parser, CInt(bitPattern:
            HTML_PARSE_RECOVER.rawValue | // don't stop due to an error or warning
            HTML_PARSE_NONET.rawValue))   // don't allow network access
        htmlParseChunk(parser, input, CInt(input.utf8.count), 1)
        htmlFreeParserCtxt(parser)

        if let mark = options.mark, result.runs[\.mark].contains(where: { $0.0 == true }) {
            for run in result.runs {
                result[run.range].setAttributes(mark.handler(run.attributes, run.mark ?? false))
            }
            result.mark = nil
        }

        if let image = options.image {
            resolve(\.imageURL, using: image.handler)
        }

        // Run `interpretedSyntax` last so that `mark`, `image`, etc. consistently run against `.full` syntax.
        switch options.interpretedSyntax {
        case .full(let resolver?):
            resolve(\.presentationIntent, using: resolver.handler)
        case .inlineOnly, .inlineOnlyPreservingWhitespace:
            resolve(\.presentationIntent, using: Options.PresentationIntentResolver.replaceWithWhitespace.handler)
        case .full:
            break
        }

        return result
    }

    // MARK: -

    func startElement(name: String?, properties: [String: String]) {
        stack.append(current)

        if let resolver = options.style, let style = properties["style"] {
            for declaration in style.split(separator: ";") {
                guard case let propertyAndValue = declaration.split(separator: ":", maxSplits: 1),
                      let property = propertyAndValue.first?.trimmingCharacters(in: .whitespaces),
                      let value = propertyAndValue.dropFirst().first?.trimmingCharacters(in: .whitespaces) else { continue }
                current.attributes = resolver.handler(current.attributes, property, value)
            }
        }

        switch name.flatMap(Tag.init) {
        case .h1:
            push(.header(level: 1))
        case .h2:
            push(.header(level: 2))
        case .h3:
            push(.header(level: 3))
        case .h4:
            push(.header(level: 4))
        case .h5:
            push(.header(level: 5))
        case .h6:
            push(.header(level: 6))
        case .p:
            push(.paragraph)
        case .center:
            push(.paragraph)
            current.attributes.center = true
        case .ol:
            push(.orderedList)
            current.listOrdinal = properties["start"].flatMap(Int.init) ?? 1
        case .ul:
            push(.unorderedList)
            current.listOrdinal = 1
        case .li:
            if let ordinal = current.listOrdinal {
                push(.listItem(ordinal: ordinal))
                current.listOrdinal = ordinal + 1
            } else {
                push(.paragraph)
            }
        case .a:
            guard options.allowsLinks else { break }
            current.attributes.link = properties["href"].flatMap(URL.init)
            current.attributes.underlineStyle = NSUnderlineStyle()
        case .em, .i:
            push(.emphasized)
        case .strong, .b:
            push(.stronglyEmphasized)
        case .mark, .bl:
            current.attributes.mark = true
        case .lb:
            stack.removeLast()
            endElement(name: "mark")
        case .br:
            current.attributes.inlinePresentationIntent = .lineBreak
            result.append(AttributedString("\n", attributes: current.attributes))
        case .img:
            let alt = properties["alt"] ?? ""
            let string = alt.isEmpty ? "\u{fffc}" : alt
            current.attributes.imageURL = properties["src"].flatMap(URL.init)
            result.append(AttributedString(string, attributes: current.attributes))
        case .body, nil:
            // All unknown tags are treated as inline containers.
            break
        }
    }

    func endElement(name: String?) {
        var context = stack.popLast() ?? Context()
        switch name.flatMap(Tag.init) {
        case .li:
            context.listOrdinal = current.listOrdinal
        case .h1, .h2, .h3, .h4, .h5, .h6, .p, .center, .ol, .ul, .body:
            // Ignore whitespace at the root when exiting a block context.
            // f.ex. `<p>Foo.</p>\n\n<p>Bar.</p>` should be `Foo.\u{2029}Bar.`.
            context.shouldLeftTrimText = stack.count < 3
            rightTrim()
        case .em, .i, .strong, .b, .mark, .bl, .lb, .a, .img, nil:
            // Stop trimming after an inline context.
            // f.ex. `Foo <b>bar</b> baz` should be `Foo bar baz`.
            context.shouldLeftTrimText = false
        case .br:
            // Don't trim out the space that was just added.
            context.shouldLeftTrimText = true
            rightTrim()
        }
        current = context
    }

    func text(_ text: String) {
        switch options.interpretedSyntax {
        case .full, .inlineOnly:
            // Replace excess whitespace with a single space.
            var text = Self.collapsableWhitespace.stringByReplacingMatches(in: text, range: NSRange(0 ..< text.utf16.count), withTemplate: " ")
            // Left-trim the text being appended if it would otherwise double up the spacing.
            if current.shouldLeftTrimText {
                text = String(text.drop(while: isRemovableWhitespace))
                current.shouldLeftTrimText = false
            }
            result.append(AttributedString(text, attributes: current.attributes))
        case .inlineOnlyPreservingWhitespace:
            result.append(AttributedString(text, attributes: current.attributes))
        }
    }

    // MARK: -

    // A least-effort emulation of how a browser handles whitespace.
    // For more details see <https://developer.mozilla.org/en-US/docs/Web/API/Document_Object_Model/Whitespace>.
    // swiftlint:disable:next force_try — Parameters checked during development
    static let collapsableWhitespace = try! NSRegularExpression(pattern: #"[\t\n\v\f\r ]+"#)

    func push(_ intent: InlinePresentationIntent) {
        current.attributes.inlinePresentationIntent = current.attributes.inlinePresentationIntent?.union(intent) ?? intent
    }

    func push(_ kind: PresentationIntent.Kind) {
        current.attributes.presentationIntent = PresentationIntent(kind, identity: identity, parent: current.attributes.presentationIntent)
        current.shouldLeftTrimText = true
        identity += 1
        rightTrim()
    }

    func isRemovableWhitespace(_ character: Character) -> Bool {
        character == " " || character == "\n"
    }

    func rightTrim(upTo upperBound: AttributedString.Index? = nil) {
        // Remove trailing whitespace, but not explicit line breaks.
        if case .inlineOnlyPreservingWhitespace = options.interpretedSyntax { return }
        let upperBound = upperBound ?? result.endIndex
        let lowerBound = result[..<upperBound].characters.reversed().drop(while: isRemovableWhitespace).startIndex.base
        let trimmedText = result[lowerBound..<upperBound]
        if let (_, lineBreakRange) = trimmedText.runs[\.inlinePresentationIntent].last(where: { $0.0?.contains(.lineBreak) == true }) {
            result.removeSubrange(lineBreakRange.upperBound ..< upperBound)
            rightTrim(upTo: lineBreakRange.lowerBound)
        } else {
            result.removeSubrange(lowerBound ..< upperBound)
        }
    }

    func isHorizontalWhitespace(_ character: Character) -> Bool {
        character == "\t" || character.unicodeScalars.first?.properties.generalCategory == .spaceSeparator
    }

    func resolve<Key>(_ key: KeyPath<AttributeDynamicLookup, Key>, upTo upperBound: AttributedString.Index? = nil, using handler: (AttributedSubstring, Key.Value?) -> AttributedString?) where Key: AttributedStringKey, Key.Value: Sendable {
        let upperBound = upperBound ?? result.endIndex
        guard let (value, range) = result[..<upperBound].runs[key].last else { return }
        if let replacement = handler(result[range], value) {
            var range = range
            if key == \.imageURL, replacement.characters.last == "\t" {
                // Left-trim if the image resolver added whitespace.
                range = range.lowerBound ..< result[range.upperBound...].characters.drop(while: isHorizontalWhitespace).startIndex
            }
            result.replaceSubrange(range, with: replacement)
        }
        resolve(key, upTo: range.lowerBound, using: handler)
    }
}

extension HTMLAttributedStringBuilder.Options.PresentationIntentResolver {
    static func listItemMarker(for component: PresentationIntent.IntentType, in components: [PresentationIntent.IntentType]) -> String {
        guard let index = components.firstIndex(where: { $0.identity == component.identity }),
              !components[..<index].contains(where: { $0.kind == .orderedList || $0.kind == .unorderedList }) else {
            // No markers for the outer lists in nested list items.
            return ""
        }

        guard case .listItem(let ordinal) = component.kind,
              case .orderedList = components[index...].dropFirst().first?.kind else {
            return "•"
        }

        return "\(ordinal.formatted())."
    }

    static let replaceWithWhitespace = Self { substring, intent in
        let components = intent?.components ?? []
        var result = AttributedString(substring)
        result.presentationIntent = nil
        var prefixWithNewline = false
        for component in components {
            switch component.kind {
            case .header:
                prefixWithNewline = true
            case .listItem:
                let marker = listItemMarker(for: component, in: components)
                result.insert(AttributedString("\(marker) "), at: result.startIndex)
            default:
                break
            }
        }
        // Detect bold text not inside a paragraph as an ambiguous heading.
        if intent == nil, substring.inlinePresentationIntent == .stronglyEmphasized {
            prefixWithNewline = true
        }
        // Synthesize line breaks between blocks.
        if substring.startIndex != substring.base.startIndex, prefixWithNewline {
            result.insert(AttributedString("\n"), at: result.startIndex)
        }
        // Synthesize a break between any blocks.
        if substring.endIndex != substring.base.endIndex {
            result.append(AttributedString("\n"))
        }
        return result
    }
}

// MARK: - Convenience

public extension AttributedString {
    /// Options that affect the parsing of HTML content into an attributed string.
    typealias HTMLParsingOptions = HTMLAttributedStringBuilder.Options

    /// Creates an attributed string from an HTML-formatted string using the provided options.
    init(html: String, options: HTMLParsingOptions) {
        let builder = HTMLAttributedStringBuilder(options: options)
        self = builder.parse(html)
    }
}

public extension NSAttributedString {
    /// Options that affect the parsing of HTML content into an attributed string.
    typealias HTMLParsingOptions = HTMLAttributedStringBuilder.Options

    /// Creates an attributed string from an HTML-formatted string using the provided options.
    convenience init(html: String, options: HTMLParsingOptions) {
        // swiftlint:disable:next force_try - None of the `objectiveCValue(for:)` methods are meant to throw.
        try! self.init(AttributedString(html: html, options: options), including: \.html)
    }
}

/// Creates a SwiftUI `Text` view that displays styled content from an HTML string.
///
/// Use this function to style text according to tags found in the given markup.
/// Attributes in the markup take precedence over styles added by view modifiers.
///
/// This method renders most inline styles, like the `<strong>` tag, which presents as bold text.
/// It also renders the `<a>` tag as a clickable link.
/// SwiftUI ignores any other unknown tags in the markup.
///
/// > Important: This function doesn't render all styling possible in HTML.
/// It doesn't support inline images or block-based formatting like block quotes, code blocks, or tables.
/// Parsing with this method treats any whitespace in the HTML string as described by the ``HTMLAttributedStringBuilder/Options/InterpretedSyntax-swift.enum/inlineOnly`` option.
///
/// - parameter html: The string that contains the HTML formatting.
public func HTML(_ html: String) -> Text {
    Text(AttributedString(html: html, options: .swiftUI))
}

public extension String {
    /// Removes the HTML formatting from a string.
    ///
    /// Use this function to remove styling you may not be expecting.
    init(html: String, preservingWhitespace: Bool = false) {
        let options = AttributedString.HTMLParsingOptions(interpretedSyntax: preservingWhitespace ? .inlineOnlyPreservingWhitespace : .inlineOnly)
        let text = AttributedString(html: html, options: options)
        self = String(text.characters)
    }
}

// MARK: - Presets

public extension HTMLAttributedStringBuilder.Options {
    /// The default configuration to build an attributed string for use by `Text`.
    static let swiftUI = Self(interpretedSyntax: .inlineOnly, style: .swiftUILabelColors, mark: .swiftUISecondaryColor)

    #if canImport(UIKit)
    /// The default configuration to build an attributed string for use by `UILabel`.
    static let uiKit = Self(interpretedSyntax: .inlineOnly, style: .uiKitLabelColors, mark: .uiKitSecondaryColor)

    /// The default configuration to build an attributed string for use with `UITextView`.
    ///
    /// - important: Use ``Foundation/NSAttributedString/init(html:options:)`` or pass `including: \.html` when converting the result to `NSAttributedString`.
    static let uiKitParagraphs = Self(interpretedSyntax: .full(.uiKitParagraphStyles), style: .uiKitLabelColors, mark: .uiKitSecondaryColor)
    #endif

    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    /// The default configuration to build an attributed string for use by `NSTextField`.
    static let appKit = Self(interpretedSyntax: .inlineOnly, style: .appKitLabelColors, mark: .appKitSecondaryColor)

    /// The default configuration to build an attributed string for use with `NSTextView`.
    static let appKitParagraphs = Self(interpretedSyntax: .full(.appKitParagraphStyles), style: .appKitLabelColors, mark: .appKitSecondaryColor)
    #endif

    /// Updates one of the properties on `self`.
    ///
    /// This method is useful for method chaining:
    ///
    /// ```swift
    /// let text = AttributedString(html: html, options: .uiKit.set(\.image, .uiKitSymbols)
    /// ```
    func set<Value>(_ keyPath: WritableKeyPath<Self, Value>, _ value: Value) -> Self {
        var result = self
        result[keyPath: keyPath] = value
        return result
    }
}

public extension HTMLAttributedStringBuilder.Options.PresentationIntentResolver {
    /// Resolves the presentation intent by creating an appropriate `NSParagraphStyle`.
    ///
    /// - important: Use ``Foundation/NSAttributedString/init(html:options:)`` or pass `including: \.html` when converting the result to `NSAttributedString`.
    private static let cocoaParagraphStyles = Self { substring, intent in
        let components = intent?.components ?? []
        var result = AttributedString(substring)
        result.presentationIntent = nil
        result.center = nil
        var paragraphStyle = AttributeScopes.HTMLAttributes.ParagraphStyleIntentAttribute()
        paragraphStyle.paragraphSpacing = 4
        paragraphStyle.alignment = substring.center == true ? .center : .natural
        paragraphStyle.defaultTabInterval = 28
        paragraphStyle.firstTab = substring.characters.starts(with: "\u{fffc}\t") ? 32 : nil
        var prefixWithNewline = false
        for component in components {
            switch component.kind {
            case .header(let level):
                result.inlinePresentationIntent = .stronglyEmphasized
                result.accessibilityHeadingLevel = AttributeScopes.AccessibilityAttributes.HeadingLevelAttribute.Value(rawValue: level)
                prefixWithNewline = true
            case .orderedList, .unorderedList:
                // If there is a paragraph style, we have to assume it applies to the entire list.
                paragraphStyle.headIndent = 28
            case .listItem:
                let marker = listItemMarker(for: component, in: components)
                result.insert(AttributedString("\(marker)\t"), at: result.startIndex)
            default:
                break
            }
        }
        // Detect bold text not inside a paragraph as an ambiguous heading.
        if intent == nil, substring.inlinePresentationIntent == .stronglyEmphasized {
            result.accessibilityHeadingLevel = .unspecified
            prefixWithNewline = true
        }
        result.paragraphStyleIntent = paragraphStyle
        // Synthesize line breaks between blocks.
        if substring.startIndex != substring.base.startIndex, prefixWithNewline {
            result.insert(AttributedString("\n"), at: result.startIndex)
        }
        if substring.endIndex != substring.base.endIndex {
            result.append(AttributedString("\n"))
        }
        return result
    }
    
    #if canImport(UIKit)
    /// Resolves the presentation intent by creating an appropriate `NSParagraphStyle`.
    ///
    /// - important: Use ``Foundation/NSAttributedString/init(html:options:)`` or pass `including: \.html` when converting the result to `NSAttributedString`.
    static var uiKitParagraphStyles: Self { cocoaParagraphStyles }
    #endif

    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    /// Resolves the presentation intent by creating an appropriate `NSParagraphStyle`.
    ///
    /// - important: Use ``Foundation/NSAttributedString/init(html:options:)`` or pass `including: \.html` when converting the result to `NSAttributedString`.
    static var appKitParagraphStyles: Self { cocoaParagraphStyles }
    #endif
}

public extension HTMLAttributedStringBuilder.Options.StyleResolver {
    private enum SystemColor: String {
        case primary
        case secondary
        case tertiary
        case quaternary
    }

    /// Resolves the `color` property to the SwiftUI label colors.
    static let swiftUILabelColors = Self { attributes, property, value in
        guard property == "color" else { return attributes }
        switch SystemColor(rawValue: value) {
        case .primary:
            return attributes.foregroundColor(Color.primary)
        case .secondary:
            return attributes.foregroundColor(Color.secondary)
        case .tertiary, .quaternary, nil:
            return attributes
        }
    }
    
    #if canImport(UIKit)
    /// Resolves the `color` property to the `UIColor` label colors.
    static let uiKitLabelColors = Self { attributes, property, value in
        guard property == "color" else { return attributes }
        switch SystemColor(rawValue: value) {
        case .primary:
            return attributes.foregroundColor(.label)
        case .secondary:
            return attributes.foregroundColor(.secondaryLabel)
        case .tertiary:
            return attributes.foregroundColor(.tertiaryLabel)
        case .quaternary:
            return attributes.foregroundColor(.quaternaryLabel)
        case nil:
            return attributes
        }
    }
    #endif

    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    /// Resolves the `color` property to the `NSColor` label colors.
    static let appKitLabelColors = Self { attributes, property, value in
        guard property == "color" else { return attributes }
        switch SystemColor(rawValue: value) {
        case .primary:
            return attributes.foregroundColor(.labelColor)
        case .secondary:
            return attributes.foregroundColor(.secondaryLabelColor)
        case .tertiary:
            return attributes.foregroundColor(.tertiaryLabelColor)
        case .quaternary:
            return attributes.foregroundColor(.quaternaryLabelColor)
        case nil:
            return attributes
        }
    }
    #endif
}

public extension HTMLAttributedStringBuilder.Options.ImageResolver {
    #if canImport(UIKit)
    /// Resolves image URLs to inline symbols.
    static let uiKitSymbols = Self { substring, _ in
        guard let url = substring.imageURL,
              // path-only URI
              url.scheme == nil, url.user == nil, url.password == nil, url.host == nil, url.port == nil, url.query == nil, url.fragment == nil,
              // relative path
              case let name = url.path,
              name.first != "/",
              // prefer system images
              let image = UIImage(systemName: name) ?? UIImage(named: name),
              image.isSymbolImage else { return nil }

        if substring.unicodeScalars.count > 1 {
            image.accessibilityLabel = String(substring.characters)
        } else {
            // If the image has no label, make sure it is seen as a decoration in `NSTextAttachment`.
            image.accessibilityTraits = .image
            image.isAccessibilityElement = true
        }

        var result = AttributedString("\u{fffc}", attributes: substring.runs[substring.startIndex].attributes)
        result.attachmentIntent = AttributeScopes.HTMLAttributes.AttachmentIntentAttribute(image: image, name: name)
        result.imageURL = nil
        // When an image occurs at the start of a paragraph, suffix it with a spacer that flexes based on the font size.
        // When there are multiple lines like this, they align on a grid.
        if let intent = substring.presentationIntent, case .paragraph = intent.components.first?.kind, intent != substring.base[..<substring.startIndex].runs.last?.presentationIntent {
            result.characters.append("\t")
        }
        return result
    }
    #endif
}

public extension HTMLAttributedStringBuilder.Options.MarkResolver {
    /// Resolves the marked text by making it bold.
    static let stronglyEmphasized = Self { attributes, isMarked in
        isMarked ? attributes.inlinePresentationIntent(.stronglyEmphasized) : attributes
    }

    /// Resolves the marked text by putting all other text in the secondary label color.
    static let swiftUISecondaryColor = Self { attributes, isMarked in
        isMarked ? attributes : attributes.foregroundColor(.secondary)
    }

    #if canImport(UIKit)
    /// Resolves the marked text by putting all other text in the secondary label color.
    static let uiKitSecondaryColor = Self { attributes, isMarked in
        isMarked ? attributes : attributes.foregroundColor(.secondaryLabel)
    }
    #endif

    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    /// Resolves the marked text by putting all other text in the secondary label color.
    static let appKitSecondaryColor = Self { attributes, isMarked in
        isMarked ? attributes : attributes.foregroundColor(.secondaryLabelColor)
    }
    #endif
}
