import SwiftUI

public extension AttributeScopes {
    /// Attribute scopes that ``HTMLAttributedStringBuilder`` defines.
    struct HTMLAttributes: AttributeScope {
        /// If `true`, the run should be highlighted.
        public enum MarkAttribute: CodableAttributedStringKey, MarkdownDecodableAttributedStringKey {
            public typealias Value = Bool
            public static let name = "mark"
        }

        /// If `true`, the run should be centered.
        public enum CenterAttribute: CodableAttributedStringKey, MarkdownDecodableAttributedStringKey {
            public typealias Value = Bool
            public static let name = "center"
        }

        /// A descriptor used to create an `NSParagraphStyle`.
        ///
        /// - since: workaround for FB12278248 (Foundation+UIKit: Using legacy keys with `AttributedString` always produces warning)
        public struct ParagraphStyleIntentAttribute: Hashable, Sendable, ObjectiveCConvertibleAttributedStringKey {
            public typealias Value = Self
            public typealias ObjectiveCValue = NSParagraphStyle

            /// The spacing between paragraphs.
            public var paragraphSpacing: CGFloat
            /// The text alignment of the paragraph.
            public var alignment: NSTextAlignment
            /// The indentation of the paragraph’s lines other than the first.
            public var headIndent: CGFloat
            /// Tabs are specified at multiples of this distance.
            public var defaultTabInterval: CGFloat
            /// The location where a leading `\t` character aligns to.
            public var firstTab: CGFloat?

            /// Creates a paragraph style intent.
            init(paragraphSpacing: CGFloat = 0, alignment: NSTextAlignment = .natural, headIndent: CGFloat = 0, defaultTabInterval: CGFloat = 28, firstTab: CGFloat? = nil) {
                self.paragraphSpacing = paragraphSpacing
                self.alignment = alignment
                self.headIndent = headIndent
                self.defaultTabInterval = defaultTabInterval
                self.firstTab = firstTab
            }

            public static var name: String {
                NSAttributedString.Key.paragraphStyle.rawValue
            }

            public static func objectiveCValue(for value: ParagraphStyleIntentAttribute) throws -> NSParagraphStyle {
                let result = ScaledParagraphStyle()
                result.paragraphSpacing = value.paragraphSpacing
                result.alignment = value.alignment
                result.headIndent = value.headIndent
                result.tabStops = value.firstTab.map { [ NSTextTab(textAlignment: .left, location: $0) ] }
                result.defaultTabInterval = value.defaultTabInterval
                return result
            }

            public static func value(for object: NSParagraphStyle) throws -> ParagraphStyleIntentAttribute {
                throw CocoaError(.featureUnsupported)
            }
        }

        #if canImport(UIKit)
        /// A descriptor used to create an `NSTextAttachment` for a symbol image.
        ///
        /// - since: workaround for FB12278248 (Foundation+UIKit: Using legacy keys with `AttributedString` always produces warning)
        public struct AttachmentIntentAttribute: Hashable, Sendable, ObjectiveCConvertibleAttributedStringKey {
            public typealias Value = Self
            public typealias ObjectiveCValue = NSTextAttachment

            /// The UIKit image used to display the symbol.
            public var image: UIImage
            /// The name used to look up a symbol image in an asset catalog.
            public var name: String?

            public static var name: String {
                NSAttributedString.Key.attachment.rawValue
            }

            public static func objectiveCValue(for value: AttachmentIntentAttribute) throws -> NSTextAttachment {
                NSTextAttachment(image: value.image)
            }

            public static func value(for object: NSTextAttachment) throws -> AttachmentIntentAttribute {
                throw CocoaError(.featureUnsupported)
            }
        }
        #endif

        public let mark: MarkAttribute
        public let center: CenterAttribute
        public let paragraphStyleIntent: ParagraphStyleIntentAttribute
        
        #if canImport(UIKit)
        public let attachmentIntent: AttachmentIntentAttribute
        public let foregroundColor: AttributeScopes.UIKitAttributes.ForegroundColorAttribute
        #endif

        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        public let foregroundColor: AttributeScopes.AppKitAttributes.ForegroundColorAttribute
        #endif

        public let foundation: AttributeScopes.FoundationAttributes
        public let accessibility: AttributeScopes.AccessibilityAttributes
    }

    /// A property for accessing the attribute scopes that ``HTMLAttributedStringBuilder`` defines.
    ///
    /// - important: Use the ``html`` namespace when converting from `AttributedString` to `NSAttributedString`.
    var html: HTMLAttributes.Type { HTMLAttributes.self }
}

public extension AttributeDynamicLookup {
    subscript<Key>(dynamicMember keyPath: KeyPath<AttributeScopes.HTMLAttributes, Key>) -> Key where Key: AttributedStringKey {
        self[Key.self]
    }
}
