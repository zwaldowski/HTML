//
//  HTMLAttributedString.swift
//  HTML
//
//  Created by Zachary Waldowski on 4/25/19.
//

#if canImport(UIKit)
import UIKit

private extension UIFont {
    static var htmlDefault: UIFont {
        preferredFont(forTextStyle: .body)
    }

    func addingSymbolicTraits(_ traits: UIFontDescriptor.SymbolicTraits) -> UIFont {
        let oldFontDescriptor = fontDescriptor
        let newSymbolicTraits = oldFontDescriptor.symbolicTraits.union(traits)
        let newFontDescriptor = oldFontDescriptor.withSymbolicTraits(newSymbolicTraits) ?? oldFontDescriptor
        return UIFont(descriptor: newFontDescriptor, size: 0)
    }

    var boldFont: UIFont {
        return addingSymbolicTraits(.traitBold)
    }

    var italicFont: UIFont {
        return addingSymbolicTraits(.traitItalic)
    }

}
#elseif canImport(AppKit)
import AppKit

private extension NSFont {
    static var htmlDefault: NSFont {
        systemFont(ofSize: NSFont.systemFontSize)
    }

    func addingSymbolicTraits(_ traits: NSFontDescriptor.SymbolicTraits) -> NSFont {
        let oldFontDescriptor = fontDescriptor
        let newSymbolicTraits = oldFontDescriptor.symbolicTraits.union(traits)
        let newFontDescriptor = oldFontDescriptor.withSymbolicTraits(newSymbolicTraits)
        return NSFont(descriptor: newFontDescriptor, size: 0) ?? self
    }

    var boldFont: NSFont {
        addingSymbolicTraits(.bold)
    }

    var italicFont: NSFont {
        addingSymbolicTraits(.italic)
    }
}
#else
import Foundation

public extension NSAttributedString.Key {
    static let font = NSAttributedString.Key("NSFont")
    static let underlineStyle = NSAttributedString.Key("NSUnderline")
    static let link = NSAttributedString.Key("NSLink")
}

private extension HTML.AttributedStringOptions.Font {
    static var htmlDefault: HTML.AttributedStringOptions.Font {
        HTML.AttributedStringOptions.Font()
    }

    var boldFont: HTML.AttributedStringOptions.Font {
        var result = self
        result.isBold = true
        return result
    }

    var italicFont: HTML.AttributedStringOptions.Font {
        var result = self
        result.isItalic = true
        return result
    }
}
#endif

// MARK: -

public extension HTML {
    struct AttributedStringOptions {
        #if canImport(UIKit)
        public typealias Font = UIFont
        public typealias UnderlineStyle = NSUnderlineStyle
        #elseif canImport(AppKit)
        public typealias Font = NSFont
        public typealias UnderlineStyle = NSUnderlineStyle
        #else
        public struct Font: Hashable {
            public var isBold = false
            public var isItalic = false
            public init() {}
        }

        public struct UnderlineStyle: OptionSet {
            public let rawValue: Int
            public init(rawValue: Int) { self.rawValue = rawValue }
            public static let single  = UnderlineStyle(rawValue: 0x01)
        }
        #endif

        public var font: Font?
        public var attributes = [NSAttributedString.Key: Any]()
        public static let `default` = AttributedStringOptions()
    }

    static func attributedString<Input>(from input: Input, options: AttributedStringOptions = .default) -> NSMutableAttributedString where Input: StringProtocol {
        (try? parse(input).attributedString(options: options)) ?? NSMutableAttributedString()
    }
}

// MARK: -

extension HTML.Node {
    func appendContents(to attributedString: NSMutableAttributedString, options: HTML.AttributedStringOptions, inheriting attributes: [NSAttributedString.Key: Any]) {
        var attributes = attributes

        switch (kind, name) {
        case (.element, "br"):
            attributedString.append(NSAttributedString(string: "\n", attributes: attributes))
        case (.element, "b"), (.element, "strong"):
            guard let currentFont = attributes[.font] as? HTML.AttributedStringOptions.Font else { break }
            attributes[.font] = currentFont.boldFont
        case (.element, "i"), (.element, "em"):
            guard let currentFont = attributes[.font] as? HTML.AttributedStringOptions.Font else { break }
            attributes[.font] = currentFont.italicFont
        case (.element, "u"):
            // `rawValue` needed due to <https://bugs.swift.org/browse/SR-3177>
            attributes[.underlineStyle] = HTML.AttributedStringOptions.UnderlineStyle.single.rawValue
        case (.element, "a"):
            guard let url = self["href"].flatMap(URL.init) else { break }
            // `rawValue` needed due to <https://bugs.swift.org/browse/SR-3177>
            attributes[.link] = url
            attributes[.underlineStyle] = HTML.AttributedStringOptions.UnderlineStyle().rawValue
        case (.element, "p"):
            if attributedString.length != 0 {
                attributedString.append(NSAttributedString(string: "\n", attributes: attributes))
            }
        case (.element, "ul"):
            if attributedString.length != 0 {
                attributedString.append(NSAttributedString(string: "\n", attributes: attributes))
            }

            let marker = "\u{2022}"
            for child in self where child.kind == .element && child.name == "li" {
                // Avoid showing a blank item for empty list items.
                let text = child.content.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { continue }
                let string = "\(marker) \(text)\n"
                attributedString.append(NSAttributedString(string: string, attributes: attributes))
            }

            return
        case (.element, "ol"):
            if attributedString.length != 0 {
                attributedString.append(NSAttributedString(string: "\n", attributes: attributes))
            }

            var marker = self["start"].flatMap(Int.init) ?? 1
            for child in self where child.kind == .element && child.name == "li" {
                // Avoid showing a blank item for empty list items.
                let text = child.content.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { continue }
                let string = "\(marker). \(text)\n"
                attributedString.append(NSAttributedString(string: string, attributes: attributes))
                marker += 1
            }

            return
        case (.element, "li"):
            // Avoid showing a blank item for empty list items.
            let text = content.trimmingCharacters(in: .whitespacesAndNewlines)
            attributedString.append(NSAttributedString(string: "\(text)\n", attributes: attributes))
            return
        case (.text, _):
            let text = content.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            if text != " " {
                attributedString.append(NSAttributedString(string: text, attributes: attributes))
            }
            return
        default:
            break
        }

        for child in self {
            child.appendContents(to: attributedString, options: options, inheriting: attributes)
        }
    }

    public func attributedString(options: HTML.AttributedStringOptions = .default) -> NSMutableAttributedString {
        var attributes = options.attributes
        attributes[.font] = options.font ?? .htmlDefault

        let attributedString = NSMutableAttributedString()
        appendContents(to: attributedString, options: options, inheriting: attributes)
        return attributedString
    }
}
