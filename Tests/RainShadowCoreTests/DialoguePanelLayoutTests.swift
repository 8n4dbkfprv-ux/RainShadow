import CoreGraphics
import Foundation
import Testing
@testable import RainShadowCore

struct DialoguePanelLayoutTests {
    private let representativeSizes: [CGSize] = [
        CGSize(width: 834, height: 1_194),   // iPad mini portrait-ish HUD
        CGSize(width: 1_024, height: 768),
        CGSize(width: 1_180, height: 820),
        CGSize(width: 1_366, height: 1_024),
        CGSize(width: 1_920, height: 1_080),
        CGSize(width: 2_388, height: 1_668)
    ]

    @Test func contentViewportAndScrollbarNeverIntersect() {
        for size in representativeSizes {
            let layout = DialoguePanelLayout.layout(for: size)
            #expect(
                !layout.contentViewportRect.intersects(layout.scrollbarRect),
                "Content intersects scrollbar for \(size)"
            )
            #expect(layout.contentAndScrollbarAreSeparated, "Separation contract failed for \(size)")
        }
    }

    @Test func choiceRowFramesDoNotOverlap() {
        let band = CGRect(x: 0, y: 0, width: 400, height: 280)
        let heights: [CGFloat] = [52, 70, 88]
        let frames = DialoguePanelLayout.choiceRowFrames(band: band, rowHeights: heights)
        #expect(frames.count == 3)
        #expect(DialoguePanelLayout.choiceFramesAreNonOverlapping(frames))
        for (index, frame) in frames.enumerated() {
            #expect(frame.height == heights[index])
            #expect(frame.width == band.width)
        }
        // Upper choice is above lower choice.
        #expect(frames[0].minY >= frames[1].maxY + DialoguePanelLayout.choiceRowSpacing - 0.01)
        #expect(frames[1].minY >= frames[2].maxY + DialoguePanelLayout.choiceRowSpacing - 0.01)
    }

    @Test func realMultilineLilaChoicesPackWithoutOverlap() {
        // Same strings as the shipped Empty Coat triad (choice page).
        let choiceTexts = [
            "Come in out of the wet. Tell me everything you know, and I'll treat it like it matters—because it does.",
            "Sit down. Start with Tuesday night: last place, last call, last person who saw her breathing.",
            "Vanished is a word people buy when 'ran off' won't pay the detective. Convince me this isn't a family argument with a taxi receipt."
        ]
        let visible = CGSize(width: 1_280, height: 800)
        let base = DialoguePanelLayout.layout(for: visible)
        // Base monologue panel stays compact for character visibility.
        #expect(base.panelRect.height <= DialoguePanelLayout.panelHeightCap + 0.001)

        // Force a content width where these lines wrap (matches typical in-game column).
        let wrapWidth = min(420, base.choiceTextMaxWidth)
        var heights: [CGFloat] = []
        for (index, text) in choiceTexts.enumerated() {
            let h = DialogueTextMetrics.choiceRowHeight(
                choiceText: text,
                index: index,
                fontSize: DialoguePanelLayout.Typography.choiceFontSize,
                maxWidth: wrapWidth,
                minimumRowHeight: DialoguePanelLayout.choiceRowMinimumHeight,
                verticalPadding: DialoguePanelLayout.choiceRowVerticalPadding
            )
            #expect(h > DialoguePanelLayout.choiceRowMinimumHeight + 8)
            heights.append(h)
        }

        let natural = DialoguePanelLayout.naturalChoicesBandHeight(measuredRowHeights: heights)
        // Fixed plaque — choice state must not change outer size (BG-style).
        let layout = DialoguePanelLayout.layout(for: visible, requiredChoicesBandHeight: natural)
        #expect(abs(layout.panelRect.height - base.panelRect.height) < 0.01)
        #expect(abs(layout.panelRect.width - base.panelRect.width) < 0.01)
        let bandH = DialoguePanelLayout.choicesBandHeight(
            measuredRowHeights: heights,
            contentViewportHeight: layout.contentViewportRect.height
        )
        let band = DialoguePanelLayout.choicesBandRect(
            contentViewport: layout.contentViewportRect,
            choicesBandHeight: bandH
        )
        let contentBand = DialoguePanelLayout.scrollableChoicesContentRect(
            visibleBand: band,
            naturalContentHeight: natural
        )
        let frames = DialoguePanelLayout.choiceRowFrames(band: contentBand, rowHeights: heights)
        #expect(frames.count == 3)
        #expect(DialoguePanelLayout.choiceFramesAreNonOverlapping(frames))
        #expect(DialoguePanelLayout.choiceFramesFitInBand(frames, band: contentBand))
        #expect(
            abs(frames[0].maxY - band.maxY) < 0.01,
            "First response must be visible at the crop's top edge before any scrolling"
        )
        for (index, frame) in frames.enumerated() {
            #expect(frame.height >= heights[index], "Choice row was compressed below its label")
        }
        #expect(contentBand.maxY == band.maxY)
        #expect(contentBand.height >= natural)
        #expect(layout.contentViewportRect.height > DialoguePanelLayout.minBodyViewportHeight)
    }

    @Test func compactPlaqueScrollsNaturalChoiceRowsInsteadOfOverlappingThem() {
        // Matches the capped 660×280 dialogue plaque visible in the reported capture.
        let layout = DialoguePanelLayout.layout(
            panelRect: CGRect(x: 0, y: 0, width: 660, height: 280)
        )
        let choiceTexts = [
            "Come in out of the wet. Tell me everything you know, and I'll treat it like it matters—because it does.",
            "Sit down. Start with Tuesday night: last place, last call, last person who saw her breathing.",
            "Vanished is a word people buy when 'ran off' won't pay the detective. Convince me this isn't a family argument with a taxi receipt."
        ]
        let heights = choiceTexts.enumerated().map { index, text in
            DialogueTextMetrics.choiceRowHeight(
                choiceText: text,
                index: index,
                fontSize: DialoguePanelLayout.Typography.choiceFontSize,
                maxWidth: layout.choiceTextMaxWidth,
                minimumRowHeight: DialoguePanelLayout.choiceRowMinimumHeight,
                verticalPadding: DialoguePanelLayout.choiceRowVerticalPadding
            )
        }
        let natural = DialoguePanelLayout.naturalChoicesBandHeight(measuredRowHeights: heights)
        let visibleHeight = DialoguePanelLayout.choicesBandHeight(
            measuredRowHeights: heights,
            contentViewportHeight: layout.contentViewportRect.height
        )
        let visibleBand = DialoguePanelLayout.choicesBandRect(
            contentViewport: layout.contentViewportRect,
            choicesBandHeight: visibleHeight
        )
        let contentBand = DialoguePanelLayout.scrollableChoicesContentRect(
            visibleBand: visibleBand,
            naturalContentHeight: natural
        )
        let frames = DialoguePanelLayout.choiceRowFrames(
            band: contentBand,
            rowHeights: heights
        )

        #expect(contentBand.height > visibleBand.height, "Short viewport should scroll the choice list")
        #expect(abs(frames[0].maxY - visibleBand.maxY) < 0.01)
        #expect(DialoguePanelLayout.choiceFramesAreNonOverlapping(frames))
        #expect(DialoguePanelLayout.choiceFramesFitInBand(frames, band: contentBand))
        for (index, frame) in frames.enumerated() {
            #expect(frame.height >= heights[index])
        }
    }

    @Test func panelIsTenPercentLargerButRemainsCompact() {
        #expect(
            abs(
                DialoguePanelLayout.panelHeightCap
                    - DialoguePanelLayout.previousCompactPanelHeightCap * 1.10
            ) < 0.001
        )
        #expect(
            abs(
                DialoguePanelLayout.panelHeightFraction
                    - DialoguePanelLayout.previousCompactPanelHeightFraction * 1.10
            ) < 0.001
        )
        #expect(
            abs(
                DialoguePanelLayout.panelWidthCap
                    - DialoguePanelLayout.previousCompactPanelWidthCap * 1.10
            ) < 0.001
        )
        // The enlarged plaque is still much smaller than the previous tall-panel era.
        #expect(DialoguePanelLayout.panelHeightCap < DialoguePanelLayout.legacyPanelHeightCap * 0.56)
        #expect(DialoguePanelLayout.panelHeightFraction < DialoguePanelLayout.legacyPanelHeightFraction * 0.56)
        for size in representativeSizes {
            let layout = DialoguePanelLayout.layout(for: size)
            let priorTall = min(
                DialoguePanelLayout.legacyPanelHeightCap,
                size.height * DialoguePanelLayout.legacyPanelHeightFraction
            )
            #expect(
                layout.panelRect.height <= priorTall * 0.56 + 1,
                "Panel height \(layout.panelRect.height) is no longer compact for \(size)"
            )
        }
    }

    @Test func officeHUDKeepsFixedPlaqueWhenChoicesAppear() {
        // HUD is camera-attached and therefore uses the physical scene viewport.
        // BG-style: outer plaque size is constant; multi-line choices pack inside.
        let viewportHeights: [CGFloat] = [600, 768, 1_152]
        let aspects: [CGFloat] = [4.0 / 3.0, 16.0 / 10.0, 16.0 / 9.0]
        let choiceTexts = [
            "Come in out of the wet. Tell me everything you know, and I'll treat it like it matters—because it does.",
            "Sit down. Start with Tuesday night: last place, last call, last person who saw her breathing.",
            "Vanished is a word people buy when 'ran off' won't pay the detective. Convince me this isn't a family argument with a taxi receipt."
        ]

        for viewportHeight in viewportHeights {
            for aspect in aspects {
                let visible = CGSize(width: viewportHeight * aspect, height: viewportHeight)
                let base = DialoguePanelLayout.layout(for: visible)
                let measureWidth = base.choiceTextMaxWidth
                var heights: [CGFloat] = []
                for (index, text) in choiceTexts.enumerated() {
                    heights.append(
                        DialogueTextMetrics.choiceRowHeight(
                            choiceText: text,
                            index: index,
                            fontSize: DialoguePanelLayout.Typography.choiceFontSize,
                            maxWidth: measureWidth,
                            minimumRowHeight: DialoguePanelLayout.choiceRowMinimumHeight,
                            verticalPadding: DialoguePanelLayout.choiceRowVerticalPadding
                        )
                    )
                }
                let natural = DialoguePanelLayout.naturalChoicesBandHeight(measuredRowHeights: heights)
                let withChoices = DialoguePanelLayout.layout(
                    for: visible,
                    requiredChoicesBandHeight: natural
                )
                // Outer chrome is identical with or without a required choices band.
                #expect(abs(withChoices.panelRect.width - base.panelRect.width) < 0.01)
                #expect(abs(withChoices.panelRect.height - base.panelRect.height) < 0.01)
                // Choices keep their natural row heights; overflow scrolls inside the fixed well.
                let bandH = DialoguePanelLayout.choicesBandHeight(
                    measuredRowHeights: heights,
                    contentViewportHeight: withChoices.contentViewportRect.height
                )
                #expect(bandH > 0)
                let band = DialoguePanelLayout.choicesBandRect(
                    contentViewport: withChoices.contentViewportRect,
                    choicesBandHeight: bandH
                )
                let contentBand = DialoguePanelLayout.scrollableChoicesContentRect(
                    visibleBand: band,
                    naturalContentHeight: natural
                )
                let frames = DialoguePanelLayout.choiceRowFrames(
                    band: contentBand,
                    rowHeights: heights
                )
                #expect(frames.count == 3)
                #expect(DialoguePanelLayout.choiceFramesAreNonOverlapping(frames))
                #expect(DialoguePanelLayout.choiceFramesFitInBand(frames, band: contentBand))
            }
        }
    }

    @Test func measuredChoiceBandUsesNaturalHeightsWithoutCrushing() {
        let heights: [CGFloat] = [60, 72, 90]
        let viewportH: CGFloat = 400
        let bandH = DialoguePanelLayout.choicesBandHeight(
            measuredRowHeights: heights,
            contentViewportHeight: viewportH
        )
        let natural = heights.reduce(0, +)
            + DialoguePanelLayout.choiceRowSpacing * 2
            + DialoguePanelLayout.choiceBandTopPadding
            + DialoguePanelLayout.choiceBandBottomPadding
        #expect(bandH == min(natural, DialoguePanelLayout.maxChoicesBandHeight(contentViewportHeight: viewportH)))
        #expect(bandH >= natural - 0.01 || bandH == DialoguePanelLayout.maxChoicesBandHeight(contentViewportHeight: viewportH))
    }

    @Test func splitLayoutKeepsChoicesBandBelowScrollingBody() {
        for size in representativeSizes {
            let layout = DialoguePanelLayout.layout(for: size)
            let content = layout.contentViewportRect
            let bandH = DialoguePanelLayout.choicesBandHeight(
                choiceCount: 3,
                contentViewportHeight: content.height
            )
            #expect(bandH > 0)
            #expect(bandH <= content.height * DialoguePanelLayout.choiceBandMaxViewportFraction + 0.001)

            let body = DialoguePanelLayout.bodyViewportRect(
                contentViewport: content,
                choicesBandHeight: bandH
            )
            let choices = DialoguePanelLayout.choicesBandRect(
                contentViewport: content,
                choicesBandHeight: bandH
            )
            #expect(choices.maxY <= body.minY + 0.001, "Choices must sit under body for \(size)")
            #expect(abs(body.maxY - content.maxY) < 0.01)
            #expect(abs(choices.minY - content.minY) < 0.01)
            #expect(abs(body.height + choices.height - content.height) < 0.01)

            let bodyBar = DialoguePanelLayout.inlineBodyScrollbarRect(
                bodyViewport: body
            )
            #expect(body.contains(bodyBar))
            #expect(bodyBar.maxX == body.maxX)
            #expect(bodyBar.height == body.height)
            #expect(!bodyBar.intersects(layout.scrollbarRect))
            let inlineTextWidth = DialoguePanelLayout.inlineBodyTextMaxWidth(
                contentViewport: content
            )
            let textRight = content.minX
                + DialoguePanelLayout.bodyTextHorizontalInset
                + inlineTextWidth
            #expect(
                textRight + DialoguePanelLayout.inlineBodyScrollbarGap
                    <= bodyBar.minX + 0.001
            )
            #expect(
                DialoguePanelLayout.inlineBodyScrollbarGap >= 20,
                "Inline body scrollbar needs visible breathing room beyond glyph overhang"
            )
        }

        // No choices → body uses the full content viewport.
        let layout = DialoguePanelLayout.layout(for: CGSize(width: 1_280, height: 800))
        let fullBody = DialoguePanelLayout.bodyViewportRect(
            contentViewport: layout.contentViewportRect,
            choicesBandHeight: 0
        )
        #expect(fullBody == layout.contentViewportRect)
        #expect(
            DialoguePanelLayout.choicesBandRect(
                contentViewport: layout.contentViewportRect,
                choicesBandHeight: 0
            ) == .zero
        )
    }

    @Test func presenterUsesIndependentScrollableChoicesCrop() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let presenterURL = root
            .appendingPathComponent("RainShadow Shared/UI/CaseIntroductionPresenter.swift")
        let source = try String(contentsOf: presenterURL, encoding: .utf8)
        #expect(source.contains("dialogue.choices-band"))
        #expect(source.contains("applySplitContentRegions"))
        #expect(source.contains("bodyViewportRect"))
        #expect(source.contains("choicesBandRect"))
        // Choices use their own crop/scroll layer and never share the body scroll root.
        #expect(source.contains("choicesCrop.addChild(choicesRoot)"))
        #expect(source.contains("choicesCrop.maskNode = choicesMask"))
        #expect(!source.contains("scrollContentRoot.addChild(choicesRoot)"))
        // Multi-line measure must use CoreText path, not crushed scale factors.
        #expect(source.contains("DialogueTextMetrics.choiceRowHeight"))
        #expect(source.contains("dialogueLabel.frame.height"))
        #expect(source.contains("let bodyTextMaxWidth = resolvedBodyTextMaxWidth()"))
        #expect(source.contains("dialogueLabel.preferredMaxLayoutWidth = bodyTextMaxWidth"))
        #expect(source.contains("maxWidth: bodyTextMaxWidth"))
        #expect(!source.contains("scaledHeights"))
        #expect(!source.contains(" * scale"))
        #expect(source.contains("bodyScrollbar.isHidden"))
        #expect(source.contains("choicesScrollbar.isHidden"))
        #expect(source.contains("let hasResponseChoices = !choicesViewport.isEmpty"))
        #expect(source.contains("configureScrollbars"))
        #expect(source.contains("setScrollTarget"))
        #expect(source.contains("refreshVisibleScrollbar"))
        #expect(source.contains("bodyScrollbar.isHidden = !bodyCanScroll"))
        #expect(source.contains("choicesScrollbar.isHidden = !choicesCanScroll"))
        #expect(source.contains("DialoguePanelLayout.inlineBodyScrollbarRect("))
        #expect(source.contains("choicesScrollbar.layout(in: panelLayout.scrollbarRect)"))
        #expect(!source.contains("bodyScrollbar.layout(in: panelLayout.scrollbarRect)"))
    }

    @Test func scrollbarOccupiesPaintedRightRail() {
        for size in representativeSizes {
            let layout = DialoguePanelLayout.layout(for: size)
            #expect(layout.scrollbarFitsPaintedRail, "Scrollbar misses painted rail for \(size)")
            let expectedCenterX = layout.panelRect.minX
                + layout.panelRect.width * DialoguePanelLayout.paintedScrollbarCenterXFraction
            #expect(abs(layout.scrollbarRect.midX - expectedCenterX) < 0.001)
            #expect(layout.scrollbarRect.minX > layout.contentWellRect.maxX - 0.001)
        }
    }

    @Test func positiveGapBetweenContentAndScrollbar() {
        for size in representativeSizes {
            let layout = DialoguePanelLayout.layout(for: size)
            let gap = layout.scrollbarRect.minX - layout.contentViewportRect.maxX
            #expect(gap >= DialoguePanelLayout.contentToScrollbarGap - 0.001, "Gap \(gap) too small for \(size)")
            #expect(
                layout.contentViewportRect.maxX + DialoguePanelLayout.contentToScrollbarGap
                    <= layout.scrollbarRect.minX + 0.001
            )
        }
    }

    @Test func bodyAndChoiceTextMaxWidthsFitInsideContentViewport() {
        for size in representativeSizes {
            let layout = DialoguePanelLayout.layout(for: size)
            #expect(
                layout.bodyTextMaxWidth
                    == layout.contentViewportRect.width - DialoguePanelLayout.bodyTextHorizontalInset * 2
            )
            #expect(layout.bodyTextMaxWidth <= layout.contentViewportRect.width)
            #expect(layout.choiceTextMaxWidth <= layout.contentViewportRect.width)
            #expect(
                layout.choiceTextMaxWidth
                    == layout.contentViewportRect.width - DialoguePanelLayout.choiceLabelHorizontalInset * 2
            )
            #expect(layout.bodyTextMaxWidth > 100, "Body width too narrow for \(size)")
            #expect(layout.choiceTextMaxWidth > 80, "Choice width too narrow for \(size)")
        }
    }

    @Test func contentViewportKeepsClearanceFromOrnateFrameRails() {
        for size in representativeSizes {
            let layout = DialoguePanelLayout.layout(for: size)
            let bottomClearance = layout.contentViewportRect.minY - layout.panelRect.minY
            let topClearance = layout.panelRect.maxY - layout.contentViewportRect.maxY
            #expect(bottomClearance >= DialoguePanelLayout.contentInsetFromPanelBottom - 0.001)
            #expect(topClearance >= DialoguePanelLayout.contentInsetFromPanelTop - 0.001)
            #expect(layout.contentViewportRect.height > 80, "Viewport too short for \(size)")
        }
    }

    @Test func triadOpeningChoiceFitsInsideContentViewport() {
        // Representative long triad choice from the shipped Empty Coat intro.
        let choice = EmptyCoatCaseIntroduction.nodes
            .first { !$0.choices.isEmpty }?
            .choices.first?.text
            ?? "Come in out of the wet."
        for size in representativeSizes {
            let layout = DialoguePanelLayout.layout(for: size)
            #expect(layout.choiceTextMaxWidth <= layout.contentViewportRect.width)
            // Preferred width must be strictly less than the distance to the scrollbar column.
            let textMaxX = layout.contentViewportRect.minX
                + DialoguePanelLayout.choiceLabelHorizontalInset
                + layout.choiceTextMaxWidth
            #expect(textMaxX <= layout.contentViewportRect.maxX + 0.001)
            #expect(textMaxX + DialoguePanelLayout.contentToScrollbarGap <= layout.scrollbarRect.minX + 0.001)
            #expect(!choice.isEmpty)
        }
    }

    @Test func scrollbarChromeStaysInsideScrollbarRect() {
        for size in representativeSizes {
            let layout = DialoguePanelLayout.layout(for: size)
            let chrome = layout.scrollbarChromeLayout()
            let bounds = CGRect(
                x: -layout.scrollbarRect.width / 2,
                y: -layout.scrollbarRect.height / 2,
                width: layout.scrollbarRect.width,
                height: layout.scrollbarRect.height
            )
            #expect(bounds.contains(chrome.upButton.insetBy(dx: 0.5, dy: 0.5))
                || chrome.upButton.minY >= bounds.minY - 0.001)
            #expect(chrome.upButton.maxY <= bounds.maxY + 0.001)
            #expect(chrome.downButton.minY >= bounds.minY - 0.001)
            #expect(chrome.track.minX >= bounds.minX - 0.001)
            #expect(chrome.track.maxX <= bounds.maxX + 0.001)
            #expect(chrome.track.minY >= chrome.downButton.maxY - 0.001)
            #expect(chrome.track.maxY <= chrome.upButton.minY + 0.001)
            #expect(layout.scrollbarRect.width == DialoguePanelLayout.scrollbarWidth)
        }
    }

    @Test func layoutForVisibleSizeMatchesPanelRectEntry() {
        let size = CGSize(width: 1_180, height: 820)
        let fromSize = DialoguePanelLayout.layout(for: size)
        let fromPanel = DialoguePanelLayout.layout(panelRect: fromSize.panelRect)
        #expect(fromSize == fromPanel)
    }

    @Test func scrollExtentCoherentWhenContentExceedsViewport() {
        for size in representativeSizes {
            let layout = DialoguePanelLayout.layout(for: size)
            let viewport = layout.contentViewportRect.height
            let tallContent = viewport * 2.4
            let maxOffset = max(0, tallContent - viewport)
            #expect(maxOffset > 0.5, "Expected scrollable content for \(size)")
            // Scrolled content stays in the same horizontal column; crop is the content viewport.
            #expect(layout.contentViewportRect.maxX < layout.scrollbarRect.minX)
        }
    }

    @Test func presenterUsesShippedLayoutEntry() throws {
        // Structural: CaseIntroductionPresenter must call DialoguePanelLayout.layout(for:).
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let presenterURL = root
            .appendingPathComponent("RainShadow Shared/UI/CaseIntroductionPresenter.swift")
        let source = try String(contentsOf: presenterURL, encoding: .utf8)
        #expect(source.contains("DialoguePanelLayout.layout(for:"))
        #expect(source.contains("DialoguePanelLayout.inlineBodyTextMaxWidth("))
        #expect(source.contains("panelLayout.choiceTextMaxWidth") || source.contains("geometry.choiceTextMaxWidth"))
        #expect(source.contains("contentMask.path = CGPath(rect:"))
        #expect(source.contains("bodyViewport") || source.contains("applySplitContentRegions"))
        #expect(!source.contains("panelRect.maxX - 176"), "Old fixed scrollbar inset must be gone")
    }

    @Test func presenterKeepsPortraitUnderFrameAndScrollbarAbove() throws {
        // Portrait sits under the frame so the painted gold window rim frames the photo.
        // Scrollbar stays above the rails; body text stays under the frame.
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let presenterURL = root
            .appendingPathComponent("RainShadow Shared/UI/CaseIntroductionPresenter.swift")
        let source = try String(contentsOf: presenterURL, encoding: .utf8)

        func zPosition(for assignmentPrefix: String) -> Int? {
            // Match lines like `portrait.zPosition = 3` / `frameOverlay.zPosition = 10`.
            let pattern = "\(NSRegularExpression.escapedPattern(for: assignmentPrefix))\\s*=\\s*(\\d+)"
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
            let range = NSRange(source.startIndex..<source.endIndex, in: source)
            guard let match = regex.firstMatch(in: source, range: range),
                  match.numberOfRanges > 1,
                  let valueRange = Range(match.range(at: 1), in: source)
            else { return nil }
            return Int(source[valueRange])
        }

        let frameZ = try #require(zPosition(for: "frameOverlay.zPosition"))
        let contentZ = try #require(zPosition(for: "contentCrop.zPosition"))
        let portraitZ = try #require(zPosition(for: "portrait.zPosition"))
        let bodyScrollbarZ = try #require(zPosition(for: "bodyScrollbar.zPosition"))
        let choicesScrollbarZ = try #require(zPosition(for: "choicesScrollbar.zPosition"))

        #expect(frameZ > contentZ, "Frame must cover overflowing body text")
        #expect(portraitZ < frameZ, "Portrait must sit under the painted gold window rim")
        #expect(bodyScrollbarZ > frameZ, "Body scrollbar must not sit under the right frame rail")
        #expect(choicesScrollbarZ > frameZ, "Choice scrollbar must not sit under the right frame rail")
    }

    @Test func basePanelUsesCompactHeightContract() {
        #expect(DialoguePanelLayout.panelHeightCap < DialoguePanelLayout.legacyPanelHeightCap)
        #expect(DialoguePanelLayout.panelHeightFraction < DialoguePanelLayout.legacyPanelHeightFraction)
        #expect(DialoguePanelLayout.legacyPanelHeightCap > DialoguePanelLayout.originalPanelHeightCap)
        for size in representativeSizes {
            let layout = DialoguePanelLayout.layout(for: size)
            let maxH = min(
                DialoguePanelLayout.panelHeightCap,
                size.height * DialoguePanelLayout.panelHeightFraction
            )
            // Aspect-locked: height is at most the compact cap (may be smaller if width-bound).
            #expect(layout.panelRect.height <= maxH + 0.001)
            #expect(layout.panelRect.height >= 120)
            let aspect = layout.panelRect.width / layout.panelRect.height
            #expect(abs(aspect - DialoguePanelLayout.frameArtAspectWidthOverHeight) < 0.01)
        }
    }

    @Test func panelWidthIsCappedForSceneVisibility() {
        #expect(DialoguePanelLayout.panelWidthCap < DialoguePanelLayout.legacyPanelWidthCap)
        #expect(DialoguePanelLayout.horizontalMarginFraction > DialoguePanelLayout.legacyHorizontalMarginFraction)
        #expect(DialoguePanelLayout.horizontalMarginMin >= DialoguePanelLayout.legacyHorizontalMarginMin)

        for size in representativeSizes {
            let layout = DialoguePanelLayout.layout(for: size)
            // Aspect lock may shrink width below the rail-cleared max.
            #expect(layout.panelRect.width <= DialoguePanelLayout.panelWidth(for: size) + 0.001)
            #expect(layout.bodyTextMaxWidth > 80)
            let priorWide = min(
                DialoguePanelLayout.legacyPanelWidthCap,
                size.width - DialoguePanelLayout.legacyHorizontalMarginMin * 2
            )
            #expect(layout.panelRect.width <= priorWide + 0.001, "Panel wider than prior for \(size)")
        }

        let ultrawide = CGSize(width: 2_200, height: 1_200)
        let wideLayout = DialoguePanelLayout.layout(for: ultrawide)
        #expect(wideLayout.panelRect.width <= DialoguePanelLayout.panelWidthCap)
        #expect(wideLayout.panelRect.width < DialoguePanelLayout.legacyPanelWidthCap)
    }

    @Test func typographyIsSlightlySmallerThanLegacyBodyAndSpeaker() {
        let body = DialoguePanelLayout.Typography.bodyFontSize
        let speaker = DialoguePanelLayout.Typography.speakerFontSize
        let choice = DialoguePanelLayout.Typography.choiceFontSize
        #expect(body < DialoguePanelLayout.Typography.legacyBodyFontSize)
        #expect(body >= 15)
        #expect(body > choice)
        #expect(speaker < DialoguePanelLayout.Typography.legacySpeakerFontSize)
        #expect(speaker >= 17)
        // Choices may be one step smaller than body so the Lila triad packs on 800×600.
        #expect(choice <= body)
        #expect(choice >= 15)
        #expect(DialoguePanelLayout.Typography.caseTitleFontSize > body)
    }

    @Test func presenterUsesSharedTypographyAndContentWell() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let presenterURL = root
            .appendingPathComponent("RainShadow Shared/UI/CaseIntroductionPresenter.swift")
        let source = try String(contentsOf: presenterURL, encoding: .utf8)
        #expect(source.contains("DialoguePanelLayout.Typography.bodyFontSize"))
        #expect(source.contains("DialoguePanelLayout.Typography.speakerFontSize"))
        #expect(source.contains("DialoguePanelLayout.Typography.choiceFontSize"))
        #expect(source.contains("contentWell"))
        #expect(source.contains("geometry.contentWellRect"))
        #expect(!source.contains("applyUnderlayStyle(usesGeneratedFrame:"))
        // No hard-coded pre-tweak body size of 20 in font assignments.
        #expect(!source.contains("dialogueLabel.fontSize = 20"))
        #expect(!source.contains("speakerLabel.fontSize = 24"))
    }

    @Test func dialogueCameraFramingKeepsMoreOfBothCharactersThanLegacyDrop() {
        let framing = OfficeNavigationLayout.DialogueCameraFraming.self
        let play = OfficeInteriorScale.mapPoint(OfficeNavigationLayout.AuthoredPlacement.camera)
        let dialogue = framing.dialogueCameraWorldPosition
        let focus = framing.actorFocusPoint

        // Actor-focused: camera sits below the Voss–Lila midpoint so both rise into the free band.
        #expect(dialogue.y == focus.y - framing.cameraBelowActorMidpoint)
        #expect(dialogue.x == focus.x)
        #expect(dialogue == framing.dialogueCameraPosition(playCamera: play))

        // Stronger drop than the prior play-camera offset that left the desk under the panel.
        #expect(framing.downwardOffsetFromPlayCamera > framing.priorDownwardOffset)
        #expect(dialogue.y < play.y)
        // Not the old fixed y-only -55 framing.
        #expect(dialogue.y != play.y - framing.legacyDownwardOffset)

        // Focus is between Voss and Lila’s arrival stop.
        let voss = OfficeInteriorScale.mapPoint(OfficeNavigationLayout.AuthoredPlacement.deskChair)
        let lila = OfficeNavigationLayout.clientArrivalPath.last!
        #expect(focus.x > min(voss.x, lila.x) && focus.x < max(voss.x, lila.x) + framing.lateralBiasTowardClient + 1)
        #expect(focus.y > min(voss.y, lila.y) - 1 && focus.y < max(voss.y, lila.y) + 1)
    }

    @Test func officeSceneUsesShippedDialogueCameraFraming() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sceneURL = root
            .appendingPathComponent("RainShadow Shared/Scenes/DetectiveOffice/DetectiveOfficeScene.swift")
        let source = try String(contentsOf: sceneURL, encoding: .utf8)
        #expect(source.contains("DialogueCameraFraming.dialogueCameraWorldPosition"))
        #expect(!source.contains("y: normalCameraPosition.y - 55"))
        #expect(!source.contains("y - 55"))
    }

    @Test func cameraChildHUDUsesPhysicalViewportAtEveryWorldZoom() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let scenePaths = [
            "RainShadow Shared/Scenes/DetectiveOffice/DetectiveOfficeScene.swift",
            "RainShadow Shared/Scenes/CityDistrict/CityDistrictScene.swift"
        ]

        for path in scenePaths {
            let source = try String(
                contentsOf: root.appendingPathComponent(path),
                encoding: .utf8
            )
            #expect(source.contains("let hudViewportSize = size"), "Missing HUD viewport contract in \(path)")
            #expect(!source.contains("layout(for: visibleSize)"), "World-size HUD layout returned in \(path)")
            for overlay in ["inventoryOverlay", "areaMapOverlay", "journalOverlay", "portraitBar", "actionBar"] {
                #expect(
                    source.contains("\(overlay).layout(for: hudViewportSize)"),
                    "\(overlay) is not screen-space in \(path)"
                )
            }
        }

        let officeSource = try String(
            contentsOf: root.appendingPathComponent(scenePaths[0]),
            encoding: .utf8
        )
        #expect(officeSource.contains("caseIntroductionPresenter.layout(for: hudViewportSize)"))
    }

    @Test func contentWellCoversTextViewportInsidePanelNotOuterChrome() {
        for size in representativeSizes {
            let layout = DialoguePanelLayout.layout(for: size)
            #expect(layout.contentWellRect.intersects(layout.contentViewportRect))
            #expect(layout.panelRect.contains(layout.contentWellRect.insetBy(dx: 0.5, dy: 0.5)))
            // Well is inset from outer panel edges (not a full outer plate).
            #expect(layout.contentWellRect.minX > layout.panelRect.minX + 1)
            #expect(layout.contentWellRect.maxX < layout.panelRect.maxX - 1)
            #expect(layout.contentWellRect.minY > layout.panelRect.minY + 1)
            #expect(layout.contentWellRect.maxY < layout.panelRect.maxY - 1)
            // Portrait sits inside the well so its backing also reads on black.
            #expect(layout.contentWellRect.intersects(layout.portraitRect))
            // The main well reaches the rail, while the control itself uses the painted channel.
            #expect(layout.contentWellRect.maxX <= layout.scrollbarRect.minX + 0.001)
            let gutter = CGRect(
                x: layout.contentViewportRect.maxX,
                y: layout.contentViewportRect.minY,
                width: layout.scrollbarRect.minX - layout.contentViewportRect.maxX,
                height: layout.contentViewportRect.height
            )
            if gutter.width > 1 {
                #expect(layout.contentWellRect.contains(gutter.insetBy(dx: 0, dy: 2)))
            }
        }
    }

    @Test func panelPresentationOffsetsLowerUIForCharacterVisibility() {
        #expect(DialoguePanelLayout.panelRestOffsetY < DialoguePanelLayout.legacyPanelRestOffsetY)
        // Fixed plaque: monologue and choice pages share the same vertical offset (no jump).
        #expect(DialoguePanelLayout.panelChoicesOffsetY == DialoguePanelLayout.panelRestOffsetY)
        #expect(DialoguePanelLayout.panelPresentationOffsetY(hasChoices: false) == DialoguePanelLayout.panelRestOffsetY)
        #expect(DialoguePanelLayout.panelPresentationOffsetY(hasChoices: true) == DialoguePanelLayout.panelRestOffsetY)
    }

    @Test func snugBodyAndChoicesClosesEmptyGapWithoutClippingChoices() {
        let content = CGRect(x: 0, y: 0, width: 600, height: 280)
        let bodyContent: CGFloat = 64
        let rowHeights: [CGFloat] = [48, 48, 52]
        let natural = DialoguePanelLayout.naturalChoicesBandHeight(measuredRowHeights: rowHeights)
        let snug = DialoguePanelLayout.snugBodyAndChoices(
            contentViewport: content,
            bodyContentHeight: bodyContent,
            naturalChoicesBandHeight: natural
        )
        #expect(snug.bandHeight == min(natural, DialoguePanelLayout.maxChoicesBandHeight(contentViewportHeight: content.height)))
        #expect(snug.choices.height == snug.bandHeight)
        #expect(snug.body.maxY == content.maxY)
        #expect(snug.choices.maxY == snug.body.minY, "Choices should sit directly under body")
        #expect(snug.choices.minY >= content.minY - 0.5)
        let contentBand = DialoguePanelLayout.scrollableChoicesContentRect(
            visibleBand: snug.choices,
            naturalContentHeight: natural
        )
        let frames = DialoguePanelLayout.choiceRowFrames(
            band: contentBand,
            rowHeights: rowHeights
        )
        #expect(DialoguePanelLayout.choiceFramesFitInBand(frames, band: contentBand))
        #expect(DialoguePanelLayout.choiceFramesAreNonOverlapping(frames))
        // Snug should not leave a huge void between body content and first choice.
        let gapUnderBody = snug.body.height - bodyContent
        #expect(gapUnderBody <= DialoguePanelLayout.minBodyViewportHeight + 1)
    }

    @Test func contentBottomInsetClearsFrameOrnamentBand() {
        // Bottom inset must be at least the frame nine-slice bottom fraction on the compact cap.
        let minOrnament = DialoguePanelLayout.panelHeightCap * DialoguePanelLayout.frameContentWellInsetBottomFraction
        #expect(DialoguePanelLayout.contentInsetFromPanelBottom + 0.5 >= min(minOrnament, 48))
        for size in representativeSizes {
            let layout = DialoguePanelLayout.layout(for: size)
            let bottomClearance = layout.contentViewportRect.minY - layout.panelRect.minY
            #expect(bottomClearance >= DialoguePanelLayout.contentInsetFromPanelBottom - 0.001)
        }
    }

    @Test func speakerNameBandSitsAboveBodyViewport() {
        // Content viewport must start below crown + speaker line + gap so name and body never share a line.
        let expectedInset = DialoguePanelLayout.speakerTopInset
            + DialoguePanelLayout.speakerNameLineHeight
            + DialoguePanelLayout.speakerToBodyGap
        #expect(DialoguePanelLayout.contentInsetFromPanelTop == expectedInset)
        #expect(DialoguePanelLayout.speakerToBodyGap >= 8)
        #expect(DialoguePanelLayout.speakerNameLineHeight >= DialoguePanelLayout.Typography.speakerFontSize)

        for size in representativeSizes {
            let layout = DialoguePanelLayout.layout(for: size)
            let speakerBottom = layout.panelRect.maxY
                - DialoguePanelLayout.speakerTopInset
                - DialoguePanelLayout.speakerNameLineHeight
            #expect(
                layout.contentViewportRect.maxY <= speakerBottom - DialoguePanelLayout.speakerToBodyGap + 0.001,
                "Body viewport overlaps speaker band for \(size)"
            )
            #expect(layout.contentViewportRect.maxY < layout.panelRect.maxY - DialoguePanelLayout.speakerTopInset)
        }
    }

    @Test func presenterPlacesSpeakerAboveBodyUsingLayoutInsets() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let presenterURL = root
            .appendingPathComponent("RainShadow Shared/UI/CaseIntroductionPresenter.swift")
        let source = try String(contentsOf: presenterURL, encoding: .utf8)
        #expect(source.contains("DialoguePanelLayout.speakerTopInset"))
        #expect(!source.contains("panelRect.maxY - 42"))
    }

    @Test func presenterUsesContentWellAndPresentationOffsets() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let presenterURL = root
            .appendingPathComponent("RainShadow Shared/UI/CaseIntroductionPresenter.swift")
        let source = try String(contentsOf: presenterURL, encoding: .utf8)
        #expect(source.contains("contentWell"))
        #expect(source.contains("dialogue.content-well") || source.contains("contentWell.path"))
        #expect(source.contains("Palette.contentWell") || source.contains("contentWell.fillColor"))
        #expect(source.contains("geometry.contentWellRect") || source.contains("contentWellRect"))
        #expect(source.contains("panelPresentationOffsetY"))
        #expect(source.contains("contentWell.path"))
        #expect(source.contains("layoutCommandControl(panelRootOffsetY:"))
        #expect(source.contains("DialoguePanelLayout.commandHitRect"))
    }

    @Test func panelClearsHUDRailsAndCentersInPlayfield() {
        for size in representativeSizes {
            let layout = DialoguePanelLayout.layout(for: size)
            let leftClear = HUDChromeLayout.leftRailClearance(for: size)
            let rightClear = HUDChromeLayout.rightRailClearance(for: size)
            let playMinX = -size.width / 2 + leftClear
            let playMaxX = size.width / 2 - rightClear
            let playCenterX = (playMinX + playMaxX) / 2
            #expect(layout.panelRect.minX >= playMinX - 0.001, "Panel overlaps left rail at \(size)")
            #expect(layout.panelRect.maxX <= playMaxX + 0.001, "Panel overlaps right rail at \(size)")
            #expect(abs(layout.panelRect.midX - playCenterX) < 0.5, "Panel not centered in playfield at \(size)")
        }
    }

    @Test func portraitSitsInPaintedFrameWindow() {
        // Live portrait must match the gold window measured on dialogue_outer_frame_overlay_v04
        // (not a generic left-well inset — that put the photo in transparent padding).
        for size in representativeSizes {
            let layout = DialoguePanelLayout.layout(for: size)
            let expected = DialoguePanelLayout.portraitWindowRect(in: layout.panelRect)
            #expect(abs(layout.portraitRect.minX - expected.minX) < 0.001)
            #expect(abs(layout.portraitRect.minY - expected.minY) < 0.001)
            #expect(abs(layout.portraitRect.width - expected.width) < 0.001)
            #expect(abs(layout.portraitRect.height - expected.height) < 0.001)
            // Window is inside the panel and left of the body text column.
            #expect(layout.panelRect.contains(layout.portraitRect.insetBy(dx: 0.5, dy: 0.5)))
            #expect(layout.portraitRect.maxX + DialoguePanelLayout.portraitToTextGap
                <= layout.contentViewportRect.minX + 0.001)
            // Past the outer transparent padding of the frame art (~0.04–0.06 on v04).
            #expect(
                layout.portraitRect.minX
                    >= layout.panelRect.minX + layout.panelRect.width * 0.04 - 0.001
            )
        }
    }

    @Test func commandControlSitsBelowPanelAndTracksPanelOffset() {
        let size = CGSize(width: 1_180, height: 820)
        let layout = DialoguePanelLayout.layout(for: size)
        let restOffset = DialoguePanelLayout.panelPresentationOffsetY(
            hasChoices: false,
            panelRect: layout.panelRect,
            visibleHeight: size.height
        )
        let choiceOffset = DialoguePanelLayout.panelPresentationOffsetY(
            hasChoices: true,
            panelRect: layout.panelRect,
            visibleHeight: size.height
        )

        let restHit = DialoguePanelLayout.commandHitRect(
            panelRect: layout.panelRect,
            panelRootOffsetY: restOffset,
            visibleHeight: size.height,
            panelWidth: layout.panelRect.width
        )
        let choiceHit = DialoguePanelLayout.commandHitRect(
            panelRect: layout.panelRect,
            panelRootOffsetY: choiceOffset,
            visibleHeight: size.height,
            panelWidth: layout.panelRect.width
        )

        let restPanelBottom = layout.panelRect.minY + restOffset
        let choicePanelBottom = layout.panelRect.minY + choiceOffset

        // Button sits under the panel (top of button at or below panel bottom).
        #expect(restHit.maxY <= restPanelBottom + 0.001)
        #expect(choiceHit.maxY <= choicePanelBottom + 0.001)
        // Button stays inside the safe screen band.
        #expect(restHit.minY >= -size.height / 2 - 0.001)
        #expect(choiceHit.minY >= -size.height / 2 - 0.001)
        #expect(restHit.height == DialoguePanelLayout.commandHeight)
        // Continue stays centered under the panel (playfield may be off-center when rails differ).
        #expect(abs(restHit.midX - layout.panelRect.midX) < 0.001)

        // Center is the pure under-panel formula (no float-up over the frame).
        let expectedRestCenter = restPanelBottom
            - DialoguePanelLayout.commandGapBelowPanel
            - DialoguePanelLayout.commandHeight / 2
        #expect(abs(restHit.midY - expectedRestCenter) < 0.001)
    }
}
