import CoreGraphics

/// Pure thumb/track math for the dialogue scrollbar. `DialogueScrollbarNode` uses these
/// formulas so tests exercise the same path as the running UI.
///
/// Geometry uses classic Mac OS 9 shapes: square arrow boxes and a proportional
/// beveled thumb, with a square minimum for a usable pointer target.
enum DialogueScrollbarGeometry {
    /// Classic scroll thumbs fill the channel edge to edge.
    static let thumbWidthInset: CGFloat = 0
    /// Minimum content overflow (pts) before the bar is considered scrollable.
    static let scrollableEpsilon: CGFloat = 0.5
    /// Largest edge of an arrow button; the bar is a fixed-width column.
    static let maximumButtonExtent: CGFloat = 30

    struct ThumbLayout: Equatable, Sendable {
        let isScrollable: Bool
        /// When false, the thumb sprite should be hidden (non-scrollable).
        let thumbVisible: Bool
        let thumbRect: CGRect
    }

    struct ChromeLayout: Equatable, Sendable {
        let upButton: CGRect
        let downButton: CGRect
        let track: CGRect
    }

    /// Arrow buttons and track inside `bounds` (the bar node's local space).
    ///
    /// Classic scroll bars share borders: the buttons sit flush against the ends of
    /// the track with no gap, so the whole control reads as one assembled widget.
    static func chromeLayout(bounds: CGRect) -> ChromeLayout {
        let buttonExtent = min(bounds.width, maximumButtonExtent)
        let upButton = CGRect(
            x: bounds.midX - buttonExtent / 2,
            y: bounds.maxY - buttonExtent,
            width: buttonExtent,
            height: buttonExtent
        )
        let downButton = CGRect(
            x: bounds.midX - buttonExtent / 2,
            y: bounds.minY,
            width: buttonExtent,
            height: buttonExtent
        )
        let track = CGRect(
            x: bounds.minX,
            y: downButton.maxY,
            width: bounds.width,
            height: max(1, upButton.minY - downButton.maxY)
        )
        return ChromeLayout(upButton: upButton, downButton: downButton, track: track)
    }

    static func isScrollable(viewportExtent: CGFloat, contentExtent: CGFloat) -> Bool {
        max(0, contentExtent - max(1, viewportExtent)) > scrollableEpsilon
    }

    /// One scroll unit: System 7 arrow clicks move exactly one line.
    static func arrowStep(lineHeight: CGFloat) -> CGFloat { max(1, lineHeight) }

    /// Gray-area click: "an entire window of information minus one scroll unit."
    static func pageStep(viewportExtent: CGFloat, lineHeight: CGFloat) -> CGFloat {
        max(lineHeight, viewportExtent - lineHeight)
    }

    /// Thumb rect in the same local space as `trackRect` (node-local after layout).
    static func thumbLayout(
        trackRect: CGRect,
        viewportExtent: CGFloat,
        contentExtent: CGFloat,
        scrollOffset: CGFloat
    ) -> ThumbLayout {
        let viewport = max(1, viewportExtent)
        let content = max(viewport, contentExtent)
        let maxOffset = max(0, content - viewport)
        let scrollable = maxOffset > scrollableEpsilon

        guard scrollable, trackRect.height > 1 else {
            return ThumbLayout(isScrollable: false, thumbVisible: false, thumbRect: .zero)
        }

        let width = max(1, trackRect.width - 2 * thumbWidthInset)
        let minimumHeight = min(width, trackRect.height)
        let height = min(trackRect.height, max(minimumHeight, trackRect.height * viewport / content))
        let travel = max(0, trackRect.height - height)
        let fraction = maxOffset > 0 ? min(1, max(0, scrollOffset / maxOffset)) : 0
        let rect = CGRect(
            x: trackRect.midX - width / 2,
            y: trackRect.maxY - height - travel * fraction,
            width: width,
            height: height
        )
        return ThumbLayout(isScrollable: true, thumbVisible: true, thumbRect: rect)
    }

    /// True when the thumb sits fully inside the track (inclusive, with tiny epsilon).
    static func thumbIsInsideTrack(thumb: CGRect, track: CGRect) -> Bool {
        guard thumb.width > 0, thumb.height > 0 else { return true }
        return thumb.minX >= track.minX - 0.01
            && thumb.maxX <= track.maxX + 0.01
            && thumb.minY >= track.minY - 0.01
            && thumb.maxY <= track.maxY + 0.01
    }
}
