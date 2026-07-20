import CoreGraphics

/// Pure geometry for the detective-office dialogue panel: content viewport,
/// scrollbar gutter, and text max width. Kept free of SpriteKit so layout
/// contracts are unit-testable and the presenter cannot drift from them.
struct DialoguePanelLayout: Equatable {
    /// Horizontal gap between the text content max-X and the scrollbar min-X.
    static let contentToScrollbarGap: CGFloat = 20

    /// Fixed width of the Mac OS 9–style scrollbar chrome column.
    static let scrollbarWidth: CGFloat = 30

    /// Minimum trailing chrome reserved for the frame’s right ornament past the bar.
    static let minimumTrailingChrome: CGFloat = 118

    /// Fraction of panel width reserved for the right frame ornament (matches
    /// the nine-slice fixed trailing rail on `dialogue_outer_frame_overlay_v02`).
    static let trailingChromeFraction: CGFloat = 0.12

    /// Horizontal inset of choice labels inside the content viewport.
    static let choiceLabelHorizontalInset: CGFloat = 14

    let panelRect: CGRect
    let portraitRect: CGRect
    let contentViewportRect: CGRect
    let scrollbarRect: CGRect
    /// Maximum layout width for body dialogue text (equals content viewport width).
    let bodyTextMaxWidth: CGFloat
    /// Maximum layout width for choice labels (content width minus label insets).
    let choiceTextMaxWidth: CGFloat

    /// Builds panel geometry from the visible HUD size (same entry the presenter uses).
    static func layout(for visibleSize: CGSize) -> DialoguePanelLayout {
        let horizontalMargin = min(72, max(36, visibleSize.width * 0.035))
        let panelWidth = min(1_500, visibleSize.width - horizontalMargin * 2)
        let commandHeight: CGFloat = 46
        let commandY = -visibleSize.height / 2 + 25
        let panelBottom = commandY + commandHeight / 2 + 8
        let panelHeight = min(360, visibleSize.height * 0.42)
        let panelRect = CGRect(
            x: -panelWidth / 2,
            y: panelBottom,
            width: panelWidth,
            height: panelHeight
        )
        return layout(panelRect: panelRect)
    }

    /// Core layout from an authored panel rect (also used by tests with fixed sizes).
    static func layout(panelRect: CGRect) -> DialoguePanelLayout {
        let trailingChrome = max(
            minimumTrailingChrome,
            panelRect.width * trailingChromeFraction
        )
        let scrollbarHeight = max(1, panelRect.height - 86)
        let scrollbarRect = CGRect(
            x: panelRect.maxX - trailingChrome - scrollbarWidth,
            y: panelRect.minY + 36,
            width: scrollbarWidth,
            height: scrollbarHeight
        )

        let portraitSize = CGSize(width: 100, height: 116)
        let portraitCenter = CGPoint(
            x: panelRect.minX + 48 + portraitSize.width / 2,
            y: panelRect.maxY - 23 - portraitSize.height / 2
        )
        let portraitRect = CGRect(
            x: portraitCenter.x - portraitSize.width / 2,
            y: portraitCenter.y - portraitSize.height / 2,
            width: portraitSize.width,
            height: portraitSize.height
        )

        let textLeft = portraitRect.maxX + 22
        let textRight = scrollbarRect.minX - contentToScrollbarGap
        let contentBottom = panelRect.minY + 32
        let contentTop = panelRect.maxY - 70
        let contentViewportRect = CGRect(
            x: textLeft,
            y: contentBottom,
            width: max(1, textRight - textLeft),
            height: max(1, contentTop - contentBottom)
        )

        let bodyTextMaxWidth = contentViewportRect.width
        let choiceTextMaxWidth = max(
            1,
            contentViewportRect.width - choiceLabelHorizontalInset * 2
        )

        return DialoguePanelLayout(
            panelRect: panelRect,
            portraitRect: portraitRect,
            contentViewportRect: contentViewportRect,
            scrollbarRect: scrollbarRect,
            bodyTextMaxWidth: bodyTextMaxWidth,
            choiceTextMaxWidth: choiceTextMaxWidth
        )
    }

    /// True when content viewport and scrollbar gutter do not intersect and keep a positive gap.
    var contentAndScrollbarAreSeparated: Bool {
        !contentViewportRect.intersects(scrollbarRect)
            && contentViewportRect.maxX + Self.contentToScrollbarGap <= scrollbarRect.minX + 0.001
            && bodyTextMaxWidth <= contentViewportRect.width + 0.001
            && choiceTextMaxWidth <= contentViewportRect.width + 0.001
    }

    /// Scrollbar chrome pieces laid out inside `scrollbarRect` (local space of the bar node).
    func scrollbarChromeLayout() -> (
        upButton: CGRect,
        downButton: CGRect,
        track: CGRect
    ) {
        let bounds = CGRect(
            x: -scrollbarRect.width / 2,
            y: -scrollbarRect.height / 2,
            width: scrollbarRect.width,
            height: scrollbarRect.height
        )
        let buttonExtent = min(scrollbarRect.width, 30)
        let gap: CGFloat = 3
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
            y: downButton.maxY + gap,
            width: bounds.width,
            height: max(1, upButton.minY - downButton.maxY - gap * 2)
        )
        return (upButton, downButton, track)
    }
}
