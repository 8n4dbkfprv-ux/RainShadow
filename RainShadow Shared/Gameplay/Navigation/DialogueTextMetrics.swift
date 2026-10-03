import CoreGraphics
import CoreText
import Foundation

/// Reliable multi-line text measurement for dialogue (SKLabelNode.frame is not trustworthy
/// until fully laid out in a scene, and often under-reports wrapped height).
enum DialogueTextMetrics {
    /// Height of `text` when wrapped to `maxWidth` with the given font.
    static func height(
        text: String,
        fontName: String,
        fontSize: CGFloat,
        maxWidth: CGFloat
    ) -> CGFloat {
        guard !text.isEmpty, maxWidth > 1, fontSize > 0 else { return 0 }

        let font = CTFontCreateWithName(fontName as CFString, fontSize, nil)
        let attrString = CFAttributedStringCreateMutable(kCFAllocatorDefault, 0)!
        CFAttributedStringReplaceString(attrString, CFRange(location: 0, length: 0), text as CFString)
        let fullRange = CFRange(location: 0, length: CFAttributedStringGetLength(attrString))
        CFAttributedStringSetAttribute(attrString, fullRange, kCTFontAttributeName, font)

        let setter = CTFramesetterCreateWithAttributedString(attrString)
        var fitRange = CFRange(location: 0, length: 0)
        let constraints = CGSize(width: maxWidth, height: CGFloat.greatestFiniteMagnitude)
        let size = CTFramesetterSuggestFrameSizeWithConstraints(
            setter,
            CFRange(location: 0, length: 0),
            nil,
            constraints,
            &fitRange
        )
        // Leading pad so descenders never collide with the next choice row.
        return max(fontSize * 1.2, ceil(size.height) + 4)
    }

    /// Row height for a numbered dialogue choice (`"1:  …"`) including vertical padding.
    static func choiceRowHeight(
        choiceText: String,
        index: Int,
        fontName: String = "Palatino-Roman",
        fontSize: CGFloat,
        maxWidth: CGFloat,
        minimumRowHeight: CGFloat,
        verticalPadding: CGFloat
    ) -> CGFloat {
        let numbered = "\(index + 1):  \(choiceText)"
        let textHeight = height(
            text: numbered,
            fontName: fontName,
            fontSize: fontSize,
            maxWidth: maxWidth
        )
        return max(minimumRowHeight, textHeight + verticalPadding)
    }
}
