import CoreGraphics

/// Pure thumb/track math for the dialogue scrollbar. `DialogueScrollbarNode` uses these
/// formulas so tests exercise the same path as the running UI.
enum DialogueScrollbarGeometry {
    /// Minimum thumb height that preserves the handle art's caps and central grip.
    static let minThumbHeight: CGFloat = 56
    /// Maximum fraction of the track a thumb may fill while still looking like a handle.
    static let maxThumbTrackFraction: CGFloat = 0.92
    /// Inset from track edges for the thumb width.
    static let thumbWidthInset: CGFloat = 5
    /// Minimum content overflow (pts) before the bar is considered scrollable.
    static let scrollableEpsilon: CGFloat = 0.5

    struct ThumbLayout: Equatable, Sendable {
        let isScrollable: Bool
        /// When false, the thumb sprite should be hidden (non-scrollable).
        let thumbVisible: Bool
        let thumbRect: CGRect
    }

    static func isScrollable(viewportExtent: CGFloat, contentExtent: CGFloat) -> Bool {
        max(0, contentExtent - max(1, viewportExtent)) > scrollableEpsilon
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
            // Non-scrollable: hide the handle so we never nine-slice a full-track strip.
            return ThumbLayout(isScrollable: false, thumbVisible: false, thumbRect: .zero)
        }

        let visibleFraction = min(1, viewport / content)
        let rawHeight = trackRect.height * visibleFraction
        let maxHeight = trackRect.height * maxThumbTrackFraction
        let thumbHeight = min(maxHeight, max(minThumbHeight, rawHeight))
        let travel = max(0, trackRect.height - thumbHeight)
        let fraction = maxOffset > 0 ? min(1, max(0, scrollOffset / maxOffset)) : 0
        let centerY = trackRect.maxY - thumbHeight / 2 - travel * fraction
        let thumbWidth = max(12, trackRect.width - thumbWidthInset * 2)
        let rect = CGRect(
            x: trackRect.midX - thumbWidth / 2,
            y: centerY - thumbHeight / 2,
            width: thumbWidth,
            height: thumbHeight
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
