import CoreGraphics

/// Pure geometry for the detective-office dialogue panel: content viewport,
/// scrollbar gutter, and text max width. Kept free of SpriteKit so layout
/// contracts are unit-testable and the presenter cannot drift from them.
struct DialoguePanelLayout: Equatable {
    /// Horizontal gap between the text content max-X and the scrollbar min-X.
    static let contentToScrollbarGap: CGFloat = 16

    /// Fixed width of the Mac OS 9–style scrollbar chrome column.
    static let scrollbarWidth: CGFloat = 30

    /// Horizontal center of the blank right gutter reserved for the live scrollbar
    /// on `dialogue_outer_frame_overlay_v08` (no painted channel — continuous well).
    static let paintedScrollbarCenterXFraction: CGFloat = 1_607.0 / 1_720.0

    /// Inner horizontal limits of the blank right gutter. The live controls
    /// must remain inside these bounds rather than floating over dialogue text.
    static let paintedScrollbarRailLeftFraction: CGFloat = 0.905
    static let paintedScrollbarRailRightFraction: CGFloat = 0.965

    /// Vertical insets of the blank right gutter measured from the frame artwork.
    static let paintedScrollbarInsetBottomFraction: CGFloat = 0.075
    static let paintedScrollbarInsetTopFraction: CGFloat = 0.075

    /// Prior compact plaque (character-visibility pass) — kept for regression tests.
    static let previousCompactPanelHeightCap: CGFloat = 280
    static let previousCompactPanelHeightFraction: CGFloat = 0.30
    static let previousCompactPanelWidthCap: CGFloat = 1_200
    /// 10% bump that briefly sat between compact and triad-fit sizing.
    static let panelScaleIncrease: CGFloat = 1.10

    /// Cap on panel height in points — fixed plaque (BG-style; does not grow for choices).
    /// Tall enough that a three-option multi-line response band fits without scrolling on
    /// typical desktop HUDs, while staying below the legacy near-fullscreen tall panel.
    /// Aspect-locked (~2.95:1): height 400 → width ≈ 1,180 at lock.
    static let panelHeightCap: CGFloat = 400
    /// Prior tall-panel height cap (pre character-visibility compact pass).
    static let legacyPanelHeightCap: CGFloat = 560
    /// Older intermediate tall-panel bump.
    static let intermediatePanelHeightCap: CGFloat = 460
    /// Older baseline before the first tall-panel bump.
    static let originalPanelHeightCap: CGFloat = 360

    /// Fraction of visible height used for the fixed plaque.
    static let panelHeightFraction: CGFloat = 0.48
    /// Prior tall-panel fraction (pre character-visibility compact pass).
    static let legacyPanelHeightFraction: CGFloat = 0.62
    static let intermediatePanelHeightFraction: CGFloat = 0.52
    static let originalPanelHeightFraction: CGFloat = 0.42

    /// Side margin fraction — modest inset so the scene shows beside the panel.
    static let horizontalMarginFraction: CGFloat = 0.06
    static let horizontalMarginMin: CGFloat = 36
    static let horizontalMarginMax: CGFloat = 96
    /// Absolute width cap so ultrawide doesn’t make lines unreadably long.
    static let panelWidthCap: CGFloat =
        previousCompactPanelWidthCap * panelScaleIncrease
    /// Prior near-full-width tall-panel era caps / margins (for regression tests).
    static let legacyPanelWidthCap: CGFloat = 2_000
    static let intermediatePanelWidthCap: CGFloat = 1_500
    static let legacyHorizontalMarginFraction: CGFloat = 0.02
    static let legacyHorizontalMarginMin: CGFloat = 20
    static let legacyHorizontalMarginMax: CGFloat = 40

    /// Inset of the text viewport from the panel bottom so body/choices clear the
    /// slim, reference-like lower rail of the v05q dialogue frame.
    static let contentInsetFromPanelBottom: CGFloat = 16

    /// Distance from panel top to the speaker name (under the slim v05q top rim).
    static let speakerTopInset: CGFloat = 20
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

    /// Outer metal rails on the uniformly scaled v05q frame.
    /// Measured on `dialogue_outer_frame_overlay_v05` (1720×583): the transparent main
    /// opening begins about 0.017 from the left and 0.043 from the top. Keep the black plate
    /// **under** the metal so it fills flush to the frame — larger insets
    /// left a strip of scene bleed at the top of the well.
    /// The frame is drawn with **uniform scale** (no nine-slice) so the painted portrait
    /// window stays aligned with layout fractions — nine-slice fixed corners previously
    /// pushed the gold window right of the live portrait.
    static let frameContentWellInsetXFraction: CGFloat = 0.010
    static let frameContentWellInsetBottomFraction: CGFloat = 0.010
    static let frameContentWellInsetTopFraction: CGFloat = 0.010
    /// Identity centerRect = stretch whole texture uniformly with `size`.
    static let frameNineSliceCenterRect = CGRect(x: 0, y: 0, width: 1, height: 1)

    /// Panel root Y offset while presenting (negative = lower = more room for actors).
    /// Same for monologue and choices so the plaque never jumps when options appear.
    static let panelRestOffsetY: CGFloat = -36
    /// Kept equal to `panelRestOffsetY` (legacy name used by older tests/call sites).
    static let panelChoicesOffsetY: CGFloat = panelRestOffsetY
    /// Prior rest offset (0) — tests document the intentional drop for character visibility.
    static let legacyPanelRestOffsetY: CGFloat = 0

    /// Continue / End control size and placement under the dialogue panel.
    static let commandHeight: CGFloat = 48
    /// Reference-shaped command artwork (`dialogue_command_button_plate_v07` 1024×116).
    static let commandArtPixelSize = CGSize(width: 1_024, height: 116)
    static let commandArtAspectWidthOverHeight: CGFloat = 1_024.0 / 116.0
    /// The authored bar already has the correct low-wide silhouette; scale it as one piece.
    static let commandFrameCenterRect = CGRect(x: 0, y: 0, width: 1, height: 1)
    static let commandGapBelowPanel: CGFloat = 10
    /// Keep the control above the physical/home-indicator band when possible.
    static let commandMinScreenBottomInset: CGFloat = 14

    /// Type sizes used by `CaseIntroductionPresenter` (pure so tests assert the contract).
    enum Typography {
        /// Body reads at a distance on the compact plaque; 16pt keeps multi-line monologue
        /// legible while staying a step above the 15pt choice rows.
        static let bodyFontSize: CGFloat = 16
        static let speakerFontSize: CGFloat = 19
        /// Slightly tighter than body copy so three multi-line options pack cleanly
        /// into the fixed plaque’s response band on typical desktop HUDs.
        static let choiceFontSize: CGFloat = 15
        /// Engraved serif command copy: slightly smaller than the former condensed sans.
        static let commandFontSize: CGFloat = 16
        static let commandLetterSpacing: CGFloat = 1.25
        static let commandShadowOffset = CGPoint(x: 0.75, y: -0.75)
        static let caseTitleFontSize: CGFloat = 22
        /// Pre-compact body size — tests assert the new body size is modestly smaller.
        static let legacyBodyFontSize: CGFloat = 18
        static let legacySpeakerFontSize: CGFloat = 22
    }

    /// Painted frame pixel size (`dialogue_outer_frame_overlay_v08` 1720×583).
    static let frameArtPixelSize = CGSize(width: 1_720, height: 583)
    /// Width / height of the shipped frame art — panel draw size must preserve this
    /// (no non-uniform squash of metal rails / portrait notch).
    static let frameArtAspectWidthOverHeight: CGFloat = 1_720.0 / 583.0

    /// Painted portrait **interior hole** on `dialogue_outer_frame_overlay_v08` (unit fractions
    /// of the full 1720×583 texture). Measured from the transparent TL well (alpha punch).
    /// The source is keyed before processing so the detached bezel stays intact with a
    /// clear green/transparent gap from the outer rails.
    /// Valid only while the frame uses uniform scale (`frameNineSliceCenterRect` full).
    static let portraitWindowLeftFraction: CGFloat = 146.0 / 1_720.0
    static let portraitWindowWidthFraction: CGFloat = 207.0 / 1_720.0
    static let portraitWindowTopFraction: CGFloat = 86.0 / 583.0
    static let portraitWindowHeightFraction: CGFloat = 169.0 / 583.0
    /// Hairline tuck under the bezel so the photo meets the metal with no black ring.
    /// Kept tiny — large insets left a visible gap between photo and frame.
    static let portraitInnerInset: CGFloat = 0.5
    /// Gap from portrait window’s right rail to the text column (must clear the bezel).
    static let portraitToTextGap: CGFloat = 14
    /// Main text well left edge on the art (right of the portrait bezel) as a floor.
    /// Measured past the v08 detached bezel outer right (~388/1720).
    static let textColumnMinLeftFraction: CGFloat = 0.245

    /// Center crop a square portrait into the reference-like vertical photo aperture
    /// without stretching the character's face.
    static var portraitTextureCropRect: CGRect {
        let displayedAspect = frameArtAspectWidthOverHeight
            * portraitWindowWidthFraction
            / portraitWindowHeightFraction
        let width = min(1, max(0.01, displayedAspect))
        return CGRect(x: (1 - width) / 2, y: 0, width: width, height: 1)
    }

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
    /// Sized so a three-option multi-line band fits without scrolling when the plaque
    /// reaches `panelHeightCap`; natural-height overflow still scrolls on tiny HUDs.
    static let choiceBandMaxViewportFraction: CGFloat = 0.76
    /// Minimum height reserved for the prompt above the response list.
    /// The body has its own crop; kept modest so three choices can claim the well.
    static let minBodyViewportHeight: CGFloat = 60
    /// Clear breathing room between Lila's body copy and its compact inline scrollbar.
    /// Palatino glyphs can overhang their measured advance slightly, so this includes
    /// enough safety space to remain visibly separate at large display scales.
    static let inlineBodyScrollbarGap: CGFloat = 24
    /// Extra headroom per choice when estimating multi-line options before measure.
    static let choiceRowEstimatedWrapSlack: CGFloat = 20
    /// Vertical padding inside a measured choice row around the label frame.
    static let choiceRowVerticalPadding: CGFloat = 8

    let panelRect: CGRect
    let portraitRect: CGRect
    let contentViewportRect: CGRect
    let scrollbarRect: CGRect
    /// Near-black plate under the frame's interior only (not the outer chrome).
    let contentWellRect: CGRect
    /// Maximum layout width for body dialogue text with no inline scrollbar reserved
    /// (content viewport minus horizontal insets). Runtime body wrapping uses
    /// `inlineBodyTextMaxWidth` instead so glyphs clear the body scrollbar.
    let bodyTextMaxWidth: CGFloat
    /// Maximum layout width for choice labels (content width minus label insets).
    let choiceTextMaxWidth: CGFloat

    /// Builds panel geometry from the visible HUD size (same entry the presenter uses).
    /// Outer plaque size is **fixed** for a given viewport (Baldur’s Gate–style): aspect-locked
    /// to the painted frame, never grown when multi-line choices appear. Choices pack into
    /// the fixed content well (scaled if needed).
    /// - Parameter requiredChoicesBandHeight: Ignored for outer size (kept for call-site
    ///   compatibility). Choice packing uses `choicesBandHeight` / `choiceRowFrames` instead.
    static func layout(
        for visibleSize: CGSize,
        requiredChoicesBandHeight: CGFloat = 0
    ) -> DialoguePanelLayout {
        _ = requiredChoicesBandHeight
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
        let fixedHeight = min(panelHeightCap, visibleSize.height * panelHeightFraction)
        let locked = aspectLockedPanelSize(maxWidth: maxWidth, maxHeight: fixedHeight)
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

    /// Fixed plaque size for a viewport (same monologue and choice pages).
    static func panelDrawSize(
        maxWidth: CGFloat,
        neededHeight: CGFloat,
        preferChoiceHeight: Bool
    ) -> CGSize {
        // preferChoiceHeight is ignored — outer chrome never grows with dialogue state.
        _ = preferChoiceHeight
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
    /// without the choice-band fraction clipping the stack.
    static func contentHeightNeeded(forNaturalChoicesBand naturalBand: CGFloat) -> CGFloat {
        guard naturalBand > 0 else { return minBodyViewportHeight }
        let byMinBody = naturalBand + minBodyViewportHeight
        let byFraction = naturalBand / max(0.01, choiceBandMaxViewportFraction)
        return max(byMinBody, byFraction) + 4
    }

    /// Fixed plaque height for the viewport (choices no longer grow the outer frame).
    static func panelHeight(
        forVisibleSize visibleSize: CGSize,
        baseHeight: CGFloat,
        requiredChoicesBandHeight: CGFloat
    ) -> CGFloat {
        _ = visibleSize
        _ = requiredChoicesBandHeight
        return baseHeight
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

    /// Live photo rect filling the painted portrait hole (panel space).
    /// Matches the hole aspect (slightly taller than wide on v05) so the square source
    /// art covers edge-to-edge under the metal bezel — no forced square letterboxing.
    static func portraitPhotoRect(in panelRect: CGRect) -> CGRect {
        let window = portraitWindowRect(in: panelRect)
        let inset = portraitInnerInset
        let photo = window.insetBy(dx: inset, dy: inset)
        return CGRect(
            x: photo.minX,
            y: photo.minY,
            width: max(1, photo.width),
            height: max(1, photo.height)
        )
    }

    /// Core layout from an authored panel rect (also used by tests with fixed sizes).
    static func layout(panelRect: CGRect) -> DialoguePanelLayout {
        // The scrollbar is a live control in the blank right gutter of the rail-free
        // v05 frame (no painted channel). The frame is aspect-locked, so source-art
        // fractions keep the control aligned at every supported viewport size.
        let scrollbarBottomInset = panelRect.height * paintedScrollbarInsetBottomFraction
        let scrollbarTopInset = panelRect.height * paintedScrollbarInsetTopFraction
        let scrollbarHeight = max(
            1,
            panelRect.height - scrollbarBottomInset - scrollbarTopInset
        )
        let scrollbarCenterX = panelRect.minX
            + panelRect.width * paintedScrollbarCenterXFraction
        let scrollbarRect = CGRect(
            x: scrollbarCenterX - scrollbarWidth / 2,
            y: panelRect.minY + scrollbarBottomInset,
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

        // Opaque black plate for the frame's main interior hole: portrait and dialogue
        // content. The blank right gutter stays clear for the live scrollbar overlay.
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

    /// Black fill covering the dialogue interior up to the blank right scrollbar gutter.
    /// Sized to sit under the slim v05 metal rim so the transparent well never shows the scene.
    static func contentWellRect(for panelRect: CGRect, scrollbarRect: CGRect) -> CGRect {
        let insetX = panelRect.width * frameContentWellInsetXFraction
        let insetBottom = panelRect.height * frameContentWellInsetBottomFraction
        let insetTop = panelRect.height * frameContentWellInsetTopFraction
        var well = CGRect(
            x: panelRect.minX + insetX,
            y: panelRect.minY + insetBottom,
            width: max(1, panelRect.width - insetX * 2),
            height: max(1, panelRect.height - insetBottom - insetTop)
        )
        // Fill the gutter up to the rail's left edge so the blank right column is also black
        // under the live scrollbar chrome.
        let scrollCoverage = CGRect(
            x: well.maxX,
            y: well.minY,
            width: max(0, scrollbarRect.minX - well.maxX),
            height: well.height
        )
        well = well.union(scrollCoverage).intersection(
            CGRect(
                x: panelRect.minX + insetX,
                y: panelRect.minY + insetBottom,
                width: max(1, scrollbarRect.minX - panelRect.minX - insetX),
                height: max(1, panelRect.height - insetBottom - insetTop)
            )
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
            && scrollbarFitsPaintedRail
    }

    /// Scrollbar controls are centered inside the recessed channel painted into the frame.
    var scrollbarFitsPaintedRail: Bool {
        let railLeft = panelRect.minX
            + panelRect.width * Self.paintedScrollbarRailLeftFraction
        let railRight = panelRect.minX
            + panelRect.width * Self.paintedScrollbarRailRightFraction
        return scrollbarRect.minX >= railLeft - 0.001
            && scrollbarRect.maxX <= railRight + 0.001
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

    /// Band height from measured row heights, clamped to the fixed plaque’s max band.
    static func choicesBandHeight(
        measuredRowHeights: [CGFloat],
        contentViewportHeight: CGFloat
    ) -> CGFloat {
        guard !measuredRowHeights.isEmpty, contentViewportHeight > 1 else { return 0 }
        let natural = naturalChoicesBandHeight(measuredRowHeights: measuredRowHeights)
        return min(natural, maxChoicesBandHeight(contentViewportHeight: contentViewportHeight))
    }

    /// Top Y of each choice row (panel space), packed top-down at its measured height.
    /// Long option lists use a cropped, scrollable content rect; row frames must never
    /// be compressed below their labels because that makes multiline text overlap.
    static func choiceRowFrames(
        band: CGRect,
        rowHeights: [CGFloat]
    ) -> [CGRect] {
        guard !rowHeights.isEmpty, band.height > 0.5 else { return [] }
        var frames: [CGRect] = []
        // Anchor the first row directly to the crop's top edge. SKLabelNode's multiline
        // `.top` alignment has additional internal ascent; subtracting top padding here
        // placed the first visible glyphs below short response bands until scrolling.
        var rowTop = band.maxY
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

    /// Full natural-height choice content, top-aligned with its visible cropped band.
    /// When `naturalContentHeight` exceeds the visible height, the content extends below
    /// the mask and scrolls upward without changing any row's measured height.
    static func scrollableChoicesContentRect(
        visibleBand: CGRect,
        naturalContentHeight: CGFloat
    ) -> CGRect {
        guard visibleBand.height > 0.5 else { return .zero }
        let height = max(visibleBand.height, naturalContentHeight)
        return CGRect(
            x: visibleBand.minX,
            y: visibleBand.maxY - height,
            width: visibleBand.width,
            height: height
        )
    }

    /// True when every packed frame sits fully inside `band` (no bottom-rail clip).
    static func choiceFramesFitInBand(_ frames: [CGRect], band: CGRect) -> Bool {
        guard !frames.isEmpty else { return true }
        return frames.allSatisfy {
            $0.minY >= band.minY - 0.5 && $0.maxY <= band.maxY + 0.5
        }
    }

    /// True when consecutive choice frames retain the authored inter-row spacing.
    static func choiceFramesAreNonOverlapping(_ frames: [CGRect]) -> Bool {
        guard frames.count >= 2 else { return true }
        for i in 0..<(frames.count - 1) {
            // frames[i] is above frames[i+1]; its lower edge must clear the next row.
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

    /// Body scrollbar beside the upper text crop. Response choices keep the painted
    /// right-hand rail; the body bar never shares that channel.
    static func inlineBodyScrollbarRect(bodyViewport: CGRect) -> CGRect {
        CGRect(
            x: bodyViewport.maxX - scrollbarWidth,
            y: bodyViewport.minY,
            width: scrollbarWidth,
            height: max(1, bodyViewport.height)
        )
    }

    /// Body wrap width when its compact scrollbar occupies the viewport's right edge.
    static func inlineBodyTextMaxWidth(contentViewport: CGRect) -> CGFloat {
        max(
            1,
            contentViewport.width
                - bodyTextHorizontalInset
                - scrollbarWidth
                - inlineBodyScrollbarGap
        )
    }

    /// Vertical panel root offset while presenting (lower = more room for actors above).
    /// Constant for monologue and choices so the plaque does not jump when options appear.
    /// Clamped so Continue always fits under the panel inside the safe screen band.
    static func panelPresentationOffsetY(
        hasChoices: Bool,
        panelRect: CGRect,
        visibleHeight: CGFloat
    ) -> CGFloat {
        _ = hasChoices
        return clampedPanelOffsetY(
            panelRect: panelRect,
            desiredOffsetY: panelRestOffsetY,
            visibleHeight: visibleHeight
        )
    }

    /// Convenience for tests that only care about the rest/choices constants.
    static func panelPresentationOffsetY(hasChoices: Bool) -> CGFloat {
        _ = hasChoices
        return panelRestOffsetY
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

    /// Fits the very shallow command artwork inside its accessible hit target without
    /// stretching the reference-like silhouette.
    static func commandPlateSize(in hitRect: CGRect) -> CGSize {
        let height = min(hitRect.height, hitRect.width / commandArtAspectWidthOverHeight)
        return CGSize(width: hitRect.width, height: max(1, height))
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
        let chrome = DialogueScrollbarGeometry.chromeLayout(bounds: bounds)
        return (chrome.upButton, chrome.downButton, chrome.track)
    }
}
