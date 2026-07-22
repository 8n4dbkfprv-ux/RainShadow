import CoreGraphics

/// Pure geometry for the detective-office dialogue panel: content viewport,
/// scrollbar gutter, and text max width. Kept free of SpriteKit so layout
/// contracts are unit-testable and the presenter cannot drift from them.
struct DialoguePanelLayout: Equatable {
    /// Horizontal gap between the text content max-X and the scrollbar min-X.
    static let contentToScrollbarGap: CGFloat = 16

    /// Fixed width of the Mac OS 9–style scrollbar chrome column.
    static let scrollbarWidth: CGFloat = 30

    /// Minimum trailing space for the frame’s right ornament (oxblood corner + metal rail).
    /// Sized so the scrollbar sits on the black content well, not over the chrome.
    static let minimumTrailingChrome: CGFloat = 168

    /// Fraction of panel width reserved for the right frame ornament (matches /
    /// exceeds the nine-slice fixed trailing rail on `dialogue_outer_frame_overlay_v02`).
    static let trailingChromeFraction: CGFloat = 0.145

    /// Extra pad left of the trailing ornament so the bar clears engraved rails.
    static let scrollbarClearanceFromTrailingChrome: CGFloat = 10

    /// Cap on panel height in points — tall enough for body + three multi-line responses.
    static let panelHeightCap: CGFloat = 560
    /// Prior height cap (pre this pass) for regression tests.
    static let legacyPanelHeightCap: CGFloat = 460
    /// Older baseline before the first tall-panel bump.
    static let originalPanelHeightCap: CGFloat = 360

    /// Fraction of visible height used for the panel.
    static let panelHeightFraction: CGFloat = 0.62
    /// Prior fraction (pre this pass) for regression tests.
    static let legacyPanelHeightFraction: CGFloat = 0.52
    static let originalPanelHeightFraction: CGFloat = 0.42

    /// Side margin fraction (BG-like near-full width; was 0.035).
    static let horizontalMarginFraction: CGFloat = 0.02
    static let horizontalMarginMin: CGFloat = 20
    static let horizontalMarginMax: CGFloat = 40
    /// Absolute width cap so ultrawide doesn’t make lines unreadably long (was 1500).
    static let panelWidthCap: CGFloat = 2_000
    static let legacyPanelWidthCap: CGFloat = 1_500
    static let legacyHorizontalMarginFraction: CGFloat = 0.035
    static let legacyHorizontalMarginMin: CGFloat = 36
    static let legacyHorizontalMarginMax: CGFloat = 72

    /// Inset of the text viewport from the panel bottom so body text never paints
    /// under the ornate bottom rail of the dialogue frame.
    static let contentInsetFromPanelBottom: CGFloat = 36

    /// Inset of the text viewport from the panel top (below speaker name / frame crown).
    static let contentInsetFromPanelTop: CGFloat = 54

    /// Extra inset of body text width inside the content viewport (keeps glyphs off the well edge).
    static let bodyTextHorizontalInset: CGFloat = 6

    /// Horizontal inset of choice labels inside the content viewport.
    static let choiceLabelHorizontalInset: CGFloat = 14

    /// Matches `dialogue_outer_frame_overlay_v02` nine-slice center (content hole).
    static let frameContentWellInsetXFraction: CGFloat = 0.11
    static let frameContentWellInsetBottomFraction: CGFloat = 0.15
    static let frameContentWellInsetTopFraction: CGFloat = 0.15

    /// Panel root Y offsets during presentation (negative = lower on screen = more room for actors).
    static let panelRestOffsetY: CGFloat = -86
    static let panelChoicesOffsetY: CGFloat = -110
    /// Prior rest offset (0) — tests document the intentional drop for character visibility.
    static let legacyPanelRestOffsetY: CGFloat = 0

    /// Continue / End control size and placement under the dialogue panel.
    static let commandHeight: CGFloat = 46
    static let commandGapBelowPanel: CGFloat = 12
    /// Keep the control above the physical/home-indicator band when possible.
    static let commandMinScreenBottomInset: CGFloat = 14

    /// Type sizes used by `CaseIntroductionPresenter` (pure so tests assert the contract).
    enum Typography {
        static let bodyFontSize: CGFloat = 18
        static let speakerFontSize: CGFloat = 22
        static let choiceFontSize: CGFloat = 18
        static let commandFontSize: CGFloat = 21
        static let caseTitleFontSize: CGFloat = 26
        /// Pre-tweak body size — tests assert the new body size is modestly smaller.
        static let legacyBodyFontSize: CGFloat = 20
        static let legacySpeakerFontSize: CGFloat = 24
    }

    /// Split layout: fixed choice band under a scrolling body (BG-like response strip).
    static let choiceRowMinimumHeight: CGFloat = 44
    static let choiceRowSpacing: CGFloat = 8
    static let choiceBandTopPadding: CGFloat = 12
    static let choiceBandBottomPadding: CGFloat = 8
    /// Choices may use most of the well when options are multi-line; body keeps a minimum strip.
    /// The 0.80 ceiling lets the longest shipped three-choice page fit at the supported
    /// 800×600 window while `minBodyViewportHeight` still protects the dialogue body.
    static let choiceBandMaxViewportFraction: CGFloat = 0.80
    /// Minimum height reserved for scrolling body text above the choice strip.
    static let minBodyViewportHeight: CGFloat = 88
    /// Extra headroom per choice when estimating multi-line options before measure.
    static let choiceRowEstimatedWrapSlack: CGFloat = 20
    /// Vertical padding inside a measured choice row around the label frame.
    static let choiceRowVerticalPadding: CGFloat = 14

    let panelRect: CGRect
    let portraitRect: CGRect
    let contentViewportRect: CGRect
    let scrollbarRect: CGRect
    /// Near-black plate under the frame's interior only (not the outer chrome).
    let contentWellRect: CGRect
    /// Maximum layout width for body dialogue text (equals content viewport width).
    let bodyTextMaxWidth: CGFloat
    /// Maximum layout width for choice labels (content width minus label insets).
    let choiceTextMaxWidth: CGFloat

    /// Builds panel geometry from the visible HUD size (same entry the presenter uses).
    /// - Parameter requiredChoicesBandHeight: When multi-line choices need more than the
    ///   default well allows, pass the **natural** (uncapped) band height so the panel
    ///   grows and every row stays inside the content viewport without scaling.
    static func layout(
        for visibleSize: CGSize,
        requiredChoicesBandHeight: CGFloat = 0
    ) -> DialoguePanelLayout {
        let panelWidth = panelWidth(for: visibleSize)
        let commandHeight: CGFloat = Self.commandHeight
        // Anchor the stack low: Continue sits under the panel inside the safe band.
        let panelBottom = -visibleSize.height / 2
            + commandMinScreenBottomInset
            + commandHeight
            + commandGapBelowPanel
            + 6
        let baseHeight = min(panelHeightCap, visibleSize.height * panelHeightFraction)
        let panelHeight = panelHeight(
            forVisibleSize: visibleSize,
            baseHeight: baseHeight,
            requiredChoicesBandHeight: requiredChoicesBandHeight
        )
        let panelRect = CGRect(
            x: -panelWidth / 2,
            y: panelBottom,
            width: panelWidth,
            height: panelHeight
        )
        return layout(panelRect: panelRect)
    }

    /// Max panel height that still leaves Continue on-screen with a sliver of free band above.
    static func maximumPanelHeight(for visibleSize: CGSize) -> CGFloat {
        max(
            200,
            visibleSize.height
                - commandMinScreenBottomInset
                - commandHeight
                - commandGapBelowPanel
                - 20
        )
    }

    /// Content viewport height needed so `naturalBand` fits under `minBodyViewportHeight`
    /// without the 0.74 fraction clipping the stack.
    static func contentHeightNeeded(forNaturalChoicesBand naturalBand: CGFloat) -> CGFloat {
        guard naturalBand > 0 else { return minBodyViewportHeight }
        let byMinBody = naturalBand + minBodyViewportHeight
        let byFraction = naturalBand / max(0.01, choiceBandMaxViewportFraction)
        return max(byMinBody, byFraction) + 4
    }

    static func panelHeight(
        forVisibleSize visibleSize: CGSize,
        baseHeight: CGFloat,
        requiredChoicesBandHeight: CGFloat
    ) -> CGFloat {
        guard requiredChoicesBandHeight > 0 else { return baseHeight }
        let neededContent = contentHeightNeeded(forNaturalChoicesBand: requiredChoicesBandHeight)
        let neededPanel = neededContent + contentInsetFromPanelTop + contentInsetFromPanelBottom
        let maxPanel = maximumPanelHeight(for: visibleSize)
        return min(maxPanel, max(baseHeight, neededPanel))
    }

    /// Uncapped band height for measured multi-line rows (source of truth for growth).
    static func naturalChoicesBandHeight(measuredRowHeights: [CGFloat]) -> CGFloat {
        guard !measuredRowHeights.isEmpty else { return 0 }
        let rowsSum = measuredRowHeights.reduce(0, +)
        let gaps = CGFloat(max(0, measuredRowHeights.count - 1)) * choiceRowSpacing
        return rowsSum + gaps + choiceBandTopPadding + choiceBandBottomPadding
    }

    /// Side inset used when sizing the dialogue panel for a given HUD width.
    static func horizontalMargin(forVisibleWidth width: CGFloat) -> CGFloat {
        min(horizontalMarginMax, max(horizontalMarginMin, width * horizontalMarginFraction))
    }

    /// Panel width: near-full HUD width (BG-like), soft-capped for ultrawide readability.
    static func panelWidth(for visibleSize: CGSize) -> CGFloat {
        let margin = horizontalMargin(forVisibleWidth: visibleSize.width)
        return min(panelWidthCap, max(1, visibleSize.width - margin * 2))
    }

    /// Core layout from an authored panel rect (also used by tests with fixed sizes).
    static func layout(panelRect: CGRect) -> DialoguePanelLayout {
        let trailingChrome = max(
            minimumTrailingChrome,
            panelRect.width * trailingChromeFraction
        )
        // Scrollbar lives in the black content hole, left of the right frame ornament.
        let scrollbarHeight = max(1, panelRect.height - 86)
        let scrollbarRect = CGRect(
            x: panelRect.maxX - trailingChrome - scrollbarClearanceFromTrailingChrome - scrollbarWidth,
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
        let contentBottom = panelRect.minY + contentInsetFromPanelBottom
        let contentTop = panelRect.maxY - contentInsetFromPanelTop
        let contentViewportRect = CGRect(
            x: textLeft,
            y: contentBottom,
            width: max(1, textRight - textLeft),
            height: max(1, contentTop - contentBottom)
        )

        let bodyTextMaxWidth = max(
            1,
            contentViewportRect.width - bodyTextHorizontalInset * 2
        )
        let choiceTextMaxWidth = max(
            1,
            contentViewportRect.width - choiceLabelHorizontalInset * 2
        )

        // Opaque black plate for the frame's entire interior hole: portrait, body, the
        // gutter beside the scrollbar, and the scrollbar column. Slightly inside the
        // outer rails so we never reintroduce a full underlay under the chrome.
        // Inset less than the nine-slice center so no floor peeks through near the bar.
        let resolvedWell = contentWellRect(for: panelRect, scrollbarRect: scrollbarRect)

        return DialoguePanelLayout(
            panelRect: panelRect,
            portraitRect: portraitRect,
            contentViewportRect: contentViewportRect,
            scrollbarRect: scrollbarRect,
            contentWellRect: resolvedWell,
            bodyTextMaxWidth: bodyTextMaxWidth,
            choiceTextMaxWidth: choiceTextMaxWidth
        )
    }

    /// Black fill covering the dialogue interior, including the empty band next to the scrollbar.
    static func contentWellRect(for panelRect: CGRect, scrollbarRect: CGRect) -> CGRect {
        // Tighter than frame rails (0.11 / 0.15) so chrome stays free; loose enough that the
        // scrollbar gutter and track never show the room through the transparent frame center.
        let insetX = panelRect.width * 0.07
        let insetBottom = panelRect.height * 0.09
        let insetTop = panelRect.height * 0.09
        var well = CGRect(
            x: panelRect.minX + insetX,
            y: panelRect.minY + insetBottom,
            width: max(1, panelRect.width - insetX * 2),
            height: max(1, panelRect.height - insetBottom - insetTop)
        )
        // Guarantee the scrollbar column and its left gutter sit fully on black.
        let scrollCoverage = scrollbarRect.insetBy(dx: -contentToScrollbarGap - 4, dy: -12)
        well = well.union(scrollCoverage).intersection(
            panelRect.insetBy(dx: panelRect.width * 0.04, dy: panelRect.height * 0.05)
        )
        if well.isNull || well.isEmpty {
            return CGRect(
                x: panelRect.minX + insetX,
                y: panelRect.minY + insetBottom,
                width: max(1, panelRect.width - insetX * 2),
                height: max(1, panelRect.height - insetBottom - insetTop)
            )
        }
        return well
    }

    /// True when content viewport and scrollbar gutter do not intersect and keep a positive gap.
    var contentAndScrollbarAreSeparated: Bool {
        !contentViewportRect.intersects(scrollbarRect)
            && contentViewportRect.maxX + Self.contentToScrollbarGap <= scrollbarRect.minX + 0.001
            && bodyTextMaxWidth <= contentViewportRect.width + 0.001
            && choiceTextMaxWidth <= contentViewportRect.width + 0.001
            && contentViewportRect.minY >= panelRect.minY + Self.contentInsetFromPanelBottom - 0.001
            && contentViewportRect.maxY <= panelRect.maxY - Self.contentInsetFromPanelTop + 0.001
            && contentWellRect.intersects(contentViewportRect)
            && panelRect.contains(contentWellRect.insetBy(dx: 1, dy: 1))
            && scrollbarClearsTrailingFrameChrome
    }

    /// Scrollbar is fully left of the reserved right ornament band (no overlap with frame art).
    var scrollbarClearsTrailingFrameChrome: Bool {
        let trailingChrome = max(
            Self.minimumTrailingChrome,
            panelRect.width * Self.trailingChromeFraction
        )
        let ornamentLeft = panelRect.maxX - trailingChrome
        return scrollbarRect.maxX <= ornamentLeft - Self.scrollbarClearanceFromTrailingChrome + 0.001
    }

    /// Estimated height of the fixed choice band for `choiceCount` options (before measure).
    static func estimatedChoicesBandHeight(choiceCount: Int) -> CGFloat {
        guard choiceCount > 0 else { return 0 }
        let rows = CGFloat(choiceCount)
        let rowBlock = rows * (choiceRowMinimumHeight + choiceRowEstimatedWrapSlack)
            + CGFloat(max(0, choiceCount - 1)) * choiceRowSpacing
        return rowBlock + choiceBandTopPadding + choiceBandBottomPadding
    }

    /// Maximum height the choice band may take without crushing the body strip.
    static func maxChoicesBandHeight(contentViewportHeight: CGFloat) -> CGFloat {
        guard contentViewportHeight > 1 else { return 0 }
        let byFraction = contentViewportHeight * choiceBandMaxViewportFraction
        let byMinBody = max(0, contentViewportHeight - minBodyViewportHeight)
        return min(byFraction, byMinBody)
    }

    /// Clamped choice-band height that never starves the scrolling body viewport.
    static func choicesBandHeight(choiceCount: Int, contentViewportHeight: CGFloat) -> CGFloat {
        guard choiceCount > 0, contentViewportHeight > 1 else { return 0 }
        let estimated = estimatedChoicesBandHeight(choiceCount: choiceCount)
        return min(estimated, maxChoicesBandHeight(contentViewportHeight: contentViewportHeight))
    }

    /// Band height from real measured row heights (never scales rows — avoids label overlap).
    /// Prefer growing the panel via `layout(for:requiredChoicesBandHeight:)` so `natural`
    /// fits; only then this equals natural rather than a clipped maxBand.
    static func choicesBandHeight(
        measuredRowHeights: [CGFloat],
        contentViewportHeight: CGFloat
    ) -> CGFloat {
        guard !measuredRowHeights.isEmpty, contentViewportHeight > 1 else { return 0 }
        let natural = naturalChoicesBandHeight(measuredRowHeights: measuredRowHeights)
        return min(natural, maxChoicesBandHeight(contentViewportHeight: contentViewportHeight))
    }

    /// Top Y of each choice row (panel space), packed top-down with no overlap.
    /// Caller must ensure `band.height >= naturalChoicesBandHeight` (grow panel first).
    static func choiceRowFrames(
        band: CGRect,
        rowHeights: [CGFloat]
    ) -> [CGRect] {
        guard !rowHeights.isEmpty, band.height > 0.5 else { return [] }
        var frames: [CGRect] = []
        var rowTop = band.maxY - choiceBandTopPadding
        for height in rowHeights {
            let h = max(choiceRowMinimumHeight, height)
            let frame = CGRect(
                x: band.minX,
                y: rowTop - h,
                width: max(1, band.width),
                height: h
            )
            frames.append(frame)
            rowTop = frame.minY - choiceRowSpacing
        }
        return frames
    }

    /// True when every packed frame sits fully inside `band` (no bottom-rail clip).
    static func choiceFramesFitInBand(_ frames: [CGRect], band: CGRect) -> Bool {
        guard !frames.isEmpty else { return true }
        return frames.allSatisfy {
            $0.minY >= band.minY - 0.5 && $0.maxY <= band.maxY + 0.5
        }
    }

    /// True when consecutive choice frames do not overlap (with spacing).
    static func choiceFramesAreNonOverlapping(_ frames: [CGRect]) -> Bool {
        guard frames.count >= 2 else { return true }
        for i in 0..<(frames.count - 1) {
            // frames[i] is above frames[i+1]; lower edge of upper must be >= upper edge of lower + spacing
            if frames[i].minY < frames[i + 1].maxY + choiceRowSpacing - 0.01 {
                return false
            }
        }
        return true
    }

    /// Scrolling body region (full content viewport when there are no choices).
    static func bodyViewportRect(
        contentViewport: CGRect,
        choicesBandHeight: CGFloat
    ) -> CGRect {
        let maxBand = maxChoicesBandHeight(contentViewportHeight: contentViewport.height)
        let band = min(max(0, choicesBandHeight), maxBand)
        guard band > 0.5 else { return contentViewport }
        return CGRect(
            x: contentViewport.minX,
            y: contentViewport.minY + band,
            width: contentViewport.width,
            height: max(1, contentViewport.height - band)
        )
    }

    /// Fixed strip for response choices at the bottom of the content viewport.
    static func choicesBandRect(
        contentViewport: CGRect,
        choicesBandHeight: CGFloat
    ) -> CGRect {
        let maxBand = maxChoicesBandHeight(contentViewportHeight: contentViewport.height)
        let band = min(max(0, choicesBandHeight), maxBand)
        guard band > 0.5 else { return .zero }
        return CGRect(
            x: contentViewport.minX,
            y: contentViewport.minY,
            width: contentViewport.width,
            height: band
        )
    }

    /// Scrollbar aligned to the body viewport only (not the fixed choice strip).
    static func bodyScrollbarRect(
        fullScrollbarRect: CGRect,
        bodyViewport: CGRect
    ) -> CGRect {
        CGRect(
            x: fullScrollbarRect.minX,
            y: bodyViewport.minY,
            width: fullScrollbarRect.width,
            height: max(1, bodyViewport.height)
        )
    }

    /// Vertical panel root offset while presenting (lower = more room for actors above).
    /// Clamped so Continue always fits under the panel inside the safe screen band.
    static func panelPresentationOffsetY(
        hasChoices: Bool,
        panelRect: CGRect,
        visibleHeight: CGFloat
    ) -> CGFloat {
        let desired = hasChoices ? panelChoicesOffsetY : panelRestOffsetY
        return clampedPanelOffsetY(
            panelRect: panelRect,
            desiredOffsetY: desired,
            visibleHeight: visibleHeight
        )
    }

    /// Convenience for tests that only care about the rest/choices constants.
    static func panelPresentationOffsetY(hasChoices: Bool) -> CGFloat {
        hasChoices ? panelChoicesOffsetY : panelRestOffsetY
    }

    /// Lowest panel bottom that still leaves room for Continue under the frame.
    static func minimumPanelBottomY(visibleHeight: CGFloat) -> CGFloat {
        -visibleHeight / 2
            + commandMinScreenBottomInset
            + commandHeight
            + commandGapBelowPanel
    }

    /// Pull the panel up if the desired drop would bury Continue off-screen.
    static func clampedPanelOffsetY(
        panelRect: CGRect,
        desiredOffsetY: CGFloat,
        visibleHeight: CGFloat
    ) -> CGFloat {
        let minBottom = minimumPanelBottomY(visibleHeight: visibleHeight)
        let desiredBottom = panelRect.minY + desiredOffsetY
        if desiredBottom >= minBottom {
            return desiredOffsetY
        }
        return minBottom - panelRect.minY
    }

    /// Center Y for Continue/End in presenter space: just under the panel (tracks panel offset).
    static func commandCenterY(
        panelRect: CGRect,
        panelRootOffsetY: CGFloat,
        visibleHeight: CGFloat
    ) -> CGFloat {
        let offset = clampedPanelOffsetY(
            panelRect: panelRect,
            desiredOffsetY: panelRootOffsetY,
            visibleHeight: visibleHeight
        )
        let panelBottom = panelRect.minY + offset
        return panelBottom - commandGapBelowPanel - commandHeight / 2
    }

    /// Hit rect for the command control, centered on X at the computed Y.
    static func commandHitRect(
        panelRect: CGRect,
        panelRootOffsetY: CGFloat,
        visibleHeight: CGFloat,
        panelWidth: CGFloat
    ) -> CGRect {
        let width = min(380, panelWidth * 0.32)
        let centerY = commandCenterY(
            panelRect: panelRect,
            panelRootOffsetY: panelRootOffsetY,
            visibleHeight: visibleHeight
        )
        return CGRect(
            x: -width / 2,
            y: centerY - commandHeight / 2,
            width: width,
            height: commandHeight
        )
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
