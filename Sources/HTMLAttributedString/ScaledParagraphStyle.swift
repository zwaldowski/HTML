import SwiftUI

/// An adaptive paragraph style that aligns tab stops based on the user's current display preferences.
public class ScaledParagraphStyle: NSMutableParagraphStyle {
    /// Creates a paragraph style with the attributes of the specified paragraph style.
    public convenience init(paragraphStyle: NSParagraphStyle) {
        self.init()
        setParagraphStyle(paragraphStyle)
    }

    /// The indentation of the paragraph’s lines other than the first.
    ///
    /// Use the ``ScaledParagraphStyle/headIndentUseFirstTabLocation`` constant to create a hanging indent.
    public override var headIndent: CGFloat {
        get {
            #if canImport(UIKit)
            // Apply a hanging indent.
            UITraitCollection.current.preferredContentSizeCategory.isAccessibilityCategory ? 0 : UIFontMetrics.default.scaledValue(for: unscaledHeadIndent)
            #else
            unscaledHeadIndent
            #endif
        }
        set {
            super.headIndent = newValue
        }
    }

    public override var tabStops: [NSTextTab]? {
        get {
            super.tabStops
        }
        set {
            super.tabStops = newValue?.map(Tab.init)
        }
    }

    public override var defaultTabInterval: CGFloat {
        get {
            #if canImport(UIKit)
            // We scale the interval to measure tabs relative to the scale of the
            // current font style. Failing to do so results in the indent tab being
            // positioned beyond the boundary from the leading margin to the end of
            // the first tab, resulting in another TAB being applied:
            //
            // TAB|
            // 1.  Lorem ipsum
            // TAB| TAB|
            // 2.      Lorem ipsum // The 2. here takes up more horizontal real estate than 1. in non-mono fonts.
            return UIFontMetrics.default.scaledValue(for: unscaledDefaultTabInterval)
            #else
            return unscaledDefaultTabInterval
            #endif
        }
        set {
            super.defaultTabInterval = newValue
        }
    }

    public override func setParagraphStyle(_ other: NSParagraphStyle) {
        super.setParagraphStyle(other)
        guard let other = other as? Self else { return }
        defaultTabInterval = other.unscaledDefaultTabInterval
        headIndent = other.unscaledHeadIndent
    }

    /// Returns a new instance with the same property values.
    public override func mutableCopy(with zone: NSZone? = nil) -> Any {
        ScaledParagraphStyle(paragraphStyle: self)
    }

    var unscaledDefaultTabInterval: CGFloat {
        super.defaultTabInterval
    }

    var unscaledHeadIndent: CGFloat {
        super.headIndent
    }

    class Tab: NSTextTab {
        convenience init(textTab other: NSTextTab) {
            self.init(textAlignment: other.alignment, location: (other as? Self)?.unscaledLocation ?? other.location, options: other.options)
        }

        override var location: CGFloat {
            #if canImport(UIKit)
            return UIFontMetrics.default.scaledValue(for: unscaledLocation)
            #else
            return unscaledLocation
            #endif
        }

        var unscaledLocation: CGFloat {
            super.location
        }
    }
}
