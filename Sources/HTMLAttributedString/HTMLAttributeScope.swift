import Accessibility
import Foundation

/// Attribute scopes that ``HTMLAttributedStringBuilder`` defines.
public struct HTMLAttributes: AttributeScope {
    /// If `true`, the run should be highlighted.
    enum MarkAttribute: CodableAttributedStringKey, MarkdownDecodableAttributedStringKey {
        typealias Value = Bool
        static let name = "mark"
    }

    /// If `true`, the run should be centered.
    enum CenterAttribute: CodableAttributedStringKey, MarkdownDecodableAttributedStringKey {
        typealias Value = Bool
        static let name = "center"
    }

    let mark: MarkAttribute
    let center: CenterAttribute
    let foundation: AttributeScopes.FoundationAttributes
    let accessibility: AttributeScopes.AccessibilityAttributes
}

public extension AttributeScopes {
    /// A property for accessing the attribute scopes that ``HTMLAttributedStringBuilder`` defines.
    var html: HTMLAttributes.Type { HTMLAttributes.self }
}

public extension AttributeDynamicLookup {
    subscript<Key>(dynamicMember keyPath: KeyPath<HTMLAttributes, Key>) -> Key where Key: AttributedStringKey {
        self[Key.self]
    }
}
