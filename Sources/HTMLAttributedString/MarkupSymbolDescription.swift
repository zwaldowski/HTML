#if canImport(UIKit)
import SwiftUI

/// A reference to a symbol image, accessible inline from `AttributedString` or `Text`.
public struct MarkupSymbolDescription {
    /// The name used to look up a symbol image in an asset catalog.
    public let name: String
    /// If `true`, the symbol comes from the SDK.
    public let isSystem: Bool
    /// The image object used to display the symbol.
    public let uiImage: UIImage
    /// The SwiftUI image used to display the symbol.
    public var image: Image {
        if isSystem {
            return Image(systemName: name)
        } else if let label = uiImage.accessibilityLabel {
            return Image(name, label: Text(label))
        } else {
            return Image(decorative: name)
        }
    }

    /// Attempts to create a symbol description from an attributed string or attributed substring.
    public init?<S>(from string: S) where S: AttributedStringProtocol {
        guard let url = string.imageURL,
              // path-only URI
              url.scheme == nil, url.user == nil, url.password == nil, url.host == nil, url.port == nil, url.query == nil, url.fragment == nil,
              // relative path
              case let name = url.path, name.first != "/" else { return nil }

        if let uiImage = UIImage(systemName: name) {
            self.uiImage = uiImage
            self.name = name
            self.isSystem = true
        } else if let uiImage = UIImage(named: name), uiImage.isSymbolImage {
            self.uiImage = uiImage
            self.name = name
            self.isSystem = false
        } else {
            return nil
        }

        if string.unicodeScalars.count > 1 {
            uiImage.accessibilityLabel = String(string.characters)
        } else {
            // If the image has no label, make sure it is seen as a decoration in `NSTextAttachment`.
            uiImage.accessibilityTraits = .image
            uiImage.isAccessibilityElement = true
        }
    }
}
#endif
