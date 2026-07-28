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
    static let minimumTrailingChrome: CGFloat = 64

    /// Fraction of panel width reserved for the right frame ornament (matches /
    /// exceeds the nine-slice fixed trailing rail on `dialogue_outer_frame_overlay_v04`).
    /// Art opaque right edge is ~0.13 of the texture (incl. outer padding).
    static let trailingChromeFraction: CGFloat = 0.14

    /// Extra pad left of the trailing ornament so the bar clears engraved rails.
    static let scrollbarClearanceFromTrailingChrome: CGFloat = 6

    /// Cap on panel height in points — compact monologue band; choice pages may grow.
    /// Sized for art aspect (~2.36:1): height 280 → width ≈ 660 at lock, keeping actors visible.
    static let panelHeightCap: CGFloat = 280
    /// Prior tall-panel height cap (pre character-visibility compact pass).
    static let legacyPanelHeightCap: CGFloat = 560
    /// Older intermediate tall-panel bump.
    static let intermediatePanelHeightCap: CGFloat = 460
    /// Older baseline before the first tall-panel bump.
    static let originalPanelHeightCap: CGFloat = 360

    /// Fraction of visible height used for the base (no-choice) panel.
    static let panelHeightFraction: CGFloat = 0.30
    /// Prior tall-panel fraction (pre character-visibility compact pass).
    static let legacyPanelHeightFraction: CGFloat = 0.62
    static let intermediatePanelHeightFraction: CGFloat = 0.52
    static let originalPanelHeightFraction: CGFloat = 0.42

    /// Side margin fraction — modest inset so the scene shows beside the panel.
    static let horizontalMarginFraction: CGFloat = 0.06
    static let horizontalMarginMin: CGFloat = 36
    static let horizontalMarginMax: CGFloat = 96
    /// Absolute width cap so ultrawide doesn’t make lines unreadably long.
    static let panelWidthCap: CGFloat = 1_200
    /// Prior near-full-width tall-panel era caps / margins (for regression tests).
    static let legacyPanelWidthCap: CGFloat = 2_000
    static let intermediatePanelWidthCap: CGFloat = 1_500
    static let legacyHorizontalMarginFraction: CGFloat = 0.02
    static let legacyHorizontalMarginMin: CGFloat = 20
    static let legacyHorizontalMarginMax: CGFloat = 40

    /// Inset of the text viewport from the panel bottom so body/choices clear the
    /// ornate oxblood corners and bottom rail of the dialogue frame (~10% of art).
    static let contentInsetFromPanelBottom: CGFloat = 36

    /// Distance from panel top to the speaker name (under the frame crown).
    /// Measured against `dialogue_outer_frame_overlay_v04` top metal (~8–10% of texture).
    static let speakerTopInset: CGFloat = 34
    /// Vertical space reserved for the speaker name line (font + breathing room).
    static let speakerNameLineHeight: CGFloat = 22
    /// Gap between the speaker name and the dialogue body.
    static let speakerToBodyGap: CGFloat = 8
    /// Inset of the text viewport from the panel top (below frame crown + speaker name).
    static let contentInsetFromPanelTop: CGFloat =
        speakerTopInset + speakerNameLineHeight + speakerToBodyGap

    /// Extra inset of body text width inside the content viewport (keeps glyphs off the well edge).
    static let bodyTextHorizontalInset: CGFloat = 10

    /// Horizontal inset of choice labels inside the content viewport.
    static let choiceLabelHorizontalInset: CGFloat = 16
    /// Extra slack under measured body text when snugging the choice band upward.
    static let bodyContentBottomSlack: CGFloat = 10

    /// Outer metal rails on the uniformly scaled frame (opaque art lives ~0.13–0.87).
    /// The frame is drawn with **uniform scale** (no nine-slice) so the painted portrait
    /// window stays aligned with layout fractions — nine-slice fixed corners previously
    /// pushed the gold window right of the live portrait.
    static let frameContentWellInsetXFraction: CGFloat = 0.145
    static let frameContentWellInsetBottomFraction: CGFloat = 0.10
    static let frameContentWellInsetTopFraction: CGFloat = 0.10
    /// Identity centerRect = stretch whole texture uniformly with `size`.
    static let frameNineSliceCenterRect = CGRect(x: 0, y: 0, width: 1, height: 1)

    /// Panel root Y offsets during presentation (negative = lower on screen = more room for actors).
    static let panelRestOffsetY: CGFloat = -36
    static let panelChoicesOffsetY: CGFloat = -48
    /// Prior rest offset (0) — tests document the intentional drop for character visibility.
    static let legacyPanelRestOffsetY: CGFloat = 0

    /// Continue / End control size and placement under the dialogue panel.
    static let commandHeight: CGFloat = 48
    static let commandGapBelowPanel: CGFloat = 10
    /// Keep the control above the physical/home-indicator band when possible.
    static let commandMinScreenBottomInset: CGFloat = 14

    /// Type sizes used by `CaseIntroductionPresenter` (pure so tests assert the contract).
    enum Typography {
        /// Body reads at a distance on the compact plaque; 17pt keeps multi-line monologue legible.
        static let bodyFontSize: CGFloat = 17
        static let speakerFontSize: CGFloat = 19
        /// Choices stay 16pt so the three-option Lila triad still packs on 800×600 without clipping.
        static let choiceFontSize: CGFloat = 16
        static let commandFontSize: CGFloat = 18
        static let caseTitleFontSize: CGFloat = 22
        /// Pre-compact body size — tests assert the new body size is modestly smaller.
        static let legacyBodyFontSize: CGFloat = 18
        static let legacySpeakerFontSize: CGFloat = 22
    }

    /// Painted frame pixel size (`dialogue_outer_frame_overlay_v04` 1720×730).
    static let frameArtPixelSize = CGSize(width: 1_720, height: 730)
    /// Width / height of the shipped frame art — panel draw size must preserve this
    /// (no non-uniform squash of metal rails / portrait notch).
    static let frameArtAspectWidthOverHeight: CGFloat = 1_720.0 / 730.0

    /// Painted portrait window on `dialogue_outer_frame_overlay_v04` (unit fractions of the
    /// full texture, including outer transparent padding). Measured from the shipped PNG
    /// metal notch (left open band ~0.05–0.21, top rail under crown ~0.10–0.42).
    /// Valid only while the frame uses uniform scale (`frameNineSliceCenterRect` full).
    static let portraitWindowLeftFraction: CGFloat = 0.053
    static let portraitWindowWidthFraction: CGFloat = 0.155
    static let portraitWindowTopFraction: CGFloat = 0.10
    static let portraitWindowHeightFraction: CGFloat = 0.32
    /// Inset inside the painted window so the photo clears the rim metal.
    static let portraitInnerInset: CGFloat = 4
    /// Gap from portrait window’s right rail to the text column (must clear the bezel).
    static let portraitToTextGap: CGFloat = 12
    /// Main text well left edge on the art (right of the portrait column chrome) as a floor.
    static let textColumnMinLeftFraction: CGFloat = 0.24

    /// Fallback HUD rail widths when a viewport is not available (tests / early layout).
    /// Prefer `HUDChromeLayout.leftRailClearance` / `rightRailClearance` when possible.
    static let hudLeftRailWidth: CGFloat = 104
    static let hudRightRailWidth: CGFloat = 124
    static let hudRailClearance: CGFloat = 10

    /// Split layout: fixed choice band under a scrolling body (BG-like response strip).
    static let choiceRowMinimumHeight: CGFloat = 40
    static let choiceRowSpacing: CGFloat = 6
    static let choiceBandTopPadding: CGFloat = 10
    /// Keep choice text above the frame’s bottom-left / bottom-right ornaments.
    static let choiceBandBottomPadding: CGFloat = 16
    /// Choices may use most of the well when options are multi-line; body keeps a minimum strip.
    /// The 0.86 ceiling lets the longest shipped three-choice page fit at the supported
    /// 800×600 window while `minBodyViewportHeight` still protects the dialogue body.
    static let choiceBandMaxViewportFraction: CGFloat = 0.86
    /// Minimum height reserved for scrolling body text above the choice strip.
    static let minBodyViewportHeight: CGFloat = 56
    /// Extra headroom per choice when estimating multi-line options before measure.
    static let choiceRowEstimatedWrapSlack: CGFloat = 20
    /// Vertical padding inside a measured choice row around the label frame.
    static let choiceRowVerticalPadding: CGFloat = 12

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
    /// Panel size is aspect-locked to `frameArtAspectWidthOverHeight` so the painted
    /// plaque is never non-uniformly stretched.
    /// - Parameter requiredChoicesBandHeight: When multi-line choices need more than the
    ///   default well allows, pass the **natural** (uncapped) band height so the panel
    ///   grows and every row stays inside the content viewport without scaling.
    static func layout(
        for visibleSize: CGSize,
        requiredChoicesBandHeight: CGFloat = 0
    ) -> DialoguePanelLayout {
        let leftClear = HUDChromeLayout.leftRailClearance(for: visibleSize)
        let rightClear = HUDChromeLayout.rightRailClearance(for: visibleSize)
        let commandHeight: CGFloat = Self.commandHeight
        // Anchor the stack low: Continue sits under the panel inside the safe band.
        let panelBottom = -visibleSize.height / 2
            + commandMinScreenBottomInset
            + commandHeight
            + commandGapBelowPanel
            + 6
        let maxWidth = panelWidth(for: visibleSize)
        let baseHeight = min(panelHeightCap, visibleSize.height * panelHeightFraction)
        let neededHeight = panelHeight(
            forVisibleSize: visibleSize,
            baseHeight: baseHeight,
            requiredChoicesBandHeight: requiredChoicesBandHeight
        )
        let locked = panelDrawSize(
            maxWidth: maxWidth,
            neededHeight: neededHeight,
            preferChoiceHeight: requiredChoicesBandHeight > 0.5
        )
        // Center in the playfield between HUD rails, not the full window.
        let playWidth = max(1, visibleSize.width - leftClear - rightClear)
        let playCenterX = -visibleSize.width / 2 + leftClear + playWidth / 2
        let panelRect = CGRect(
            x: playCenterX - locked.width / 2,
            y: panelBottom,
            width: locked.width,
            height: locked.height
        )
        return layout(panelRect: panelRect)
    }

    /// Largest panel size that fits in `maxWidth`×`maxHeight` while preserving frame art aspect.
    static func aspectLockedPanelSize(maxWidth: CGFloat, maxHeight: CGFloat) -> CGSize {
        let aspect = frameArtAspectWidthOverHeight
        let byWidth = CGSize(width: maxWidth, height: maxWidth / aspect)
        if byWidth.height <= maxHeight + 0.001 {
            return CGSize(width: max(1, byWidth.width), height: max(1, byWidth.height))
        }
        let byHeight = CGSize(width: maxHeight * aspect, height: maxHeight)
        return CGSize(width: max(1, byHeight.width), height: max(1, byHeight.height))
    }

    /// Monologue pages stay art-aspect locked. Choice pages prefer the height needed
    /// for multi-line options; they keep art aspect when width allows, otherwise keep
    /// the required height at max width so response rows never clip.
    static func panelDrawSize(
        maxWidth: CGFloat,
        neededHeight: CGFloat,
        preferChoiceHeight: Bool
    ) -> CGSize {
        let aspect = frameArtAspectWidthOverHeight
        if preferChoiceHeight {
            let idealWidth = neededHeight * aspect
            if idealWidth <= maxWidth + 0.001 {
                return CGSize(width: max(1, idealWidth), height: max(1, neededHeight))
            }
            return CGSize(width: max(1, maxWidth), height: max(1, neededHeight))
        }
        return aspectLockedPanelSize(maxWidth: maxWidth, maxHeight: neededHeight)
    }

    /// Max panel height that still leaves Continue on-screen with a sliver of free band above.
    static func maximumPanelHeight(for visibleSize: CGSize) -> CGFloat {
        max(
            200,
            visibleSize.height
                - commandMinScreenBottomInset
                - commandHeight
                - commandGapBelowPanel
                - 8
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

    /// Panel width: fits between HUD rails with a soft ultrawide cap.
    /// Rails already clear the chrome; only a small gap keeps the frame from kissing them.
    static func panelWidth(for visibleSize: CGSize) -> CGFloat {
        let leftClear = HUDChromeLayout.leftRailClearance(for: visibleSize)
        let rightClear = HUDChromeLayout.rightRailClearance(for: visibleSize)
        let railGap: CGFloat = 16
        let available = visibleSize.width - leftClear - rightClear - railGap
        return min(panelWidthCap, max(1, available))
    }

    /// Live photo rect fully inside the painted portrait window (panel space).
    static func portraitPhotoRect(in panelRect: CGRect) -> CGRect {
        let window = portraitWindowRect(in: panelRect)
        let inset = portraitInnerInset
        let side = max(1, min(window.width, window.height) - inset * 2)
        return CGRect(
            x: window.midX - side / 2,
            y: window.midY - side / 2,
            width: side,
            height: side
        )
    }

    /// Core layout from an authored panel rect (also used by tests with fixed sizes).
    static func layout(panelRect: CGRect) -> DialoguePanelLayout {
        let trailingChrome = max(
            minimumTrailingChrome,
            panelRect.width * trailingChromeFraction
        )
        // Ornament bands scale with panel height (uniform frame); cap so choice growth
        // still expands the text well rather than ever-thicker rails.
        let wellInsetTop = min(
            panelRect.height * frameContentWellInsetTopFraction,
            panelHeightCap * frameContentWellInsetTopFraction
        )
        let wellInsetBottom = min(
            panelRect.height * frameContentWellInsetBottomFraction,
            panelHeightCap * frameContentWellInsetBottomFraction
        )

        // Scrollbar lives in the black content hole, left of the right frame ornament.
        let scrollbarHeight = max(1, panelRect.height - wellInsetTop - wellInsetBottom - 8)
        let scrollbarRect = CGRect(
            x: panelRect.maxX - trailingChrome - scrollbarClearanceFromTrailingChrome - scrollbarWidth,
            y: panelRect.minY + wellInsetBottom + 4,
            width: scrollbarWidth,
            height: scrollbarHeight
        )

        // Live portrait sits in the painted gold window (uniform-scale frame fractions).
        let portraitRect = portraitWindowRect(in: panelRect)

        // Text column clears both the live portrait and the painted column chrome.
        let textLeft = max(
            portraitRect.maxX + portraitToTextGap,
            panelRect.minX + panelRect.width * textColumnMinLeftFraction
        )
        let textRight = scrollbarRect.minX - contentToScrollbarGap
        // Fixed insets so choice-driven panel growth expands the text viewport 1:1.
        // Body sits under the speaker line, to the right of the portrait column.
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

    /// Painted portrait window rect in panel space (matches the gold rim on the frame art).
    static func portraitWindowRect(in panelRect: CGRect) -> CGRect {
        let x = panelRect.minX + panelRect.width * portraitWindowLeftFraction
        let height = max(1, panelRect.height * portraitWindowHeightFraction)
        let y = panelRect.maxY - panelRect.height * portraitWindowTopFraction - height
        let width = max(1, panelRect.width * portraitWindowWidthFraction)
        return CGRect(x: x, y: y, width: width, height: height)
    }

    /// Black fill covering the dialogue interior, including the empty band next to the scrollbar.
    static func contentWellRect(for panelRect: CGRect, scrollbarRect: CGRect) -> CGRect {
        // Opaque frame metal lives at ~0.13–0.87 of the texture; stay inside that hole.
        let insetX = panelRect.width * 0.145
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
            panelRect.insetBy(dx: panelRect.width * 0.12, dy: panelRect.height * 0.06)
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

    /// When body text is short, lift the choice band so a large empty black gap does not
    /// sit between dialogue and responses. Choices keep their natural height and stay
    /// inside the content well; body never shrinks below `minBodyViewportHeight`.
    static func snugBodyAndChoices(
        contentViewport: CGRect,
        bodyContentHeight: CGFloat,
        naturalChoicesBandHeight: CGFloat
    ) -> (body: CGRect, choices: CGRect, bandHeight: CGFloat) {
        let maxBand = maxChoicesBandHeight(contentViewportHeight: contentViewport.height)
        let bandHeight = min(max(0, naturalChoicesBandHeight), maxBand)
        guard bandHeight > 0.5 else {
            return (contentViewport, .zero, 0)
        }

        let preferredBody = max(
            minBodyViewportHeight,
            bodyContentHeight + bodyContentBottomSlack
        )
        // Body takes only what it needs (or the minimum); leftover sits above choices.
        let bodyHeight = min(preferredBody, contentViewport.height - bandHeight)
        let resolvedBodyHeight = max(minBodyViewportHeight, bodyHeight)
        // If min body + band exceeds the well, fall back to classic bottom-aligned split.
        if resolvedBodyHeight + bandHeight > contentViewport.height + 0.5 {
            let body = bodyViewportRect(
                contentViewport: contentViewport,
                choicesBandHeight: bandHeight
            )
            let choices = choicesBandRect(
                contentViewport: contentViewport,
                choicesBandHeight: bandHeight
            )
            return (body, choices, bandHeight)
        }

        let body = CGRect(
            x: contentViewport.minX,
            y: contentViewport.maxY - resolvedBodyHeight,
            width: contentViewport.width,
            height: resolvedBodyHeight
        )
        // Sit the choice band directly under the body (snug), not stuck to the well floor
        // with a void in between — unless that would push under the well floor.
        let choicesMinY = max(contentViewport.minY, body.minY - bandHeight)
        let choices = CGRect(
            x: contentViewport.minX,
            y: choicesMinY,
            width: contentViewport.width,
            height: bandHeight
        )
        let finalBody = CGRect(
            x: contentViewport.minX,
            y: choices.maxY,
            width: contentViewport.width,
            height: max(1, contentViewport.maxY - choices.maxY)
        )
        return (finalBody, choices, bandHeight)
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

    /// Hit rect for the command control, centered under the panel.
    static func commandHitRect(
        panelRect: CGRect,
        panelRootOffsetY: CGFloat,
        visibleHeight: CGFloat,
        panelWidth: CGFloat
    ) -> CGRect {
        let width = min(420, panelWidth * 0.38)
        let centerY = commandCenterY(
            panelRect: panelRect,
            panelRootOffsetY: panelRootOffsetY,
            visibleHeight: visibleHeight
        )
        return CGRect(
            x: panelRect.midX - width / 2,
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
