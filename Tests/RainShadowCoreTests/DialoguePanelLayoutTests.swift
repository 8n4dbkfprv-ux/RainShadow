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
        let layout = DialoguePanelLayout.layout(for: visible, requiredChoicesBandHeight: natural)
        let bandH = DialoguePanelLayout.choicesBandHeight(
            measuredRowHeights: heights,
            contentViewportHeight: layout.contentViewportRect.height
        )
        let band = DialoguePanelLayout.choicesBandRect(
            contentViewport: layout.contentViewportRect,
            choicesBandHeight: bandH
        )
        let frames = DialoguePanelLayout.choiceRowFrames(band: band, rowHeights: heights)
        #expect(frames.count == 3)
        #expect(DialoguePanelLayout.choiceFramesAreNonOverlapping(frames))
        for (index, frame) in frames.enumerated() {
            #expect(frame.height >= heights[index] - 0.01)
            #expect(frame.minY >= band.minY - 0.5, "Choice \(index) clipped below band")
        }
        // Grown choice panel still leaves a usable body strip above the responses.
        #expect(layout.contentViewportRect.height > DialoguePanelLayout.minBodyViewportHeight)
        #expect(layout.panelRect.height >= base.panelRect.height)
    }

    @Test func panelIsCompactForCharacterVisibility() {
        // Compact monologue band is ~half the prior tall panel so actors stay on screen.
        #expect(DialoguePanelLayout.panelHeightCap <= DialoguePanelLayout.legacyPanelHeightCap * 0.5 + 0.001)
        #expect(DialoguePanelLayout.panelHeightFraction <= DialoguePanelLayout.legacyPanelHeightFraction * 0.5 + 0.001)
        for size in representativeSizes {
            let layout = DialoguePanelLayout.layout(for: size)
            let priorTall = min(
                DialoguePanelLayout.legacyPanelHeightCap,
                size.height * DialoguePanelLayout.legacyPanelHeightFraction
            )
            #expect(
                layout.panelRect.height <= priorTall * 0.5 + 1,
                "Panel height \(layout.panelRect.height) not ≤ half of prior tall \(priorTall) for \(size)"
            )
        }
    }

    @Test func officeHUDGrowsSoMultilineTriadFitsWithoutClipping() {
        // HUD is camera-attached and therefore uses the physical scene viewport,
        // independent of the world camera's visible height.
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
                // First pass: base layout (what was too short for natural multi-line rows).
                let base = DialoguePanelLayout.layout(for: visible)
                var heights: [CGFloat] = []
                for (index, text) in choiceTexts.enumerated() {
                    heights.append(
                        DialogueTextMetrics.choiceRowHeight(
                            choiceText: text,
                            index: index,
                            fontSize: DialoguePanelLayout.Typography.choiceFontSize,
                            maxWidth: base.choiceTextMaxWidth,
                            minimumRowHeight: DialoguePanelLayout.choiceRowMinimumHeight,
                            verticalPadding: DialoguePanelLayout.choiceRowVerticalPadding
                        )
                    )
                }
                let natural = DialoguePanelLayout.naturalChoicesBandHeight(measuredRowHeights: heights)
                let baseMaxBand = DialoguePanelLayout.maxChoicesBandHeight(
                    contentViewportHeight: base.contentViewportRect.height
                )
                // Office HUD is the case that overflowed when natural > baseMaxBand.
                // Grown layout must fit natural stack fully.
                let grown = DialoguePanelLayout.layout(
                    for: visible,
                    requiredChoicesBandHeight: natural
                )
                #expect(grown.panelRect.height >= base.panelRect.height - 0.001)
                let grownMaxBand = DialoguePanelLayout.maxChoicesBandHeight(
                    contentViewportHeight: grown.contentViewportRect.height
                )
                #expect(
                    grownMaxBand + 0.5 >= natural,
                    "Grown maxBand \(grownMaxBand) < natural \(natural) at \(visible)"
                )
                let bandH = DialoguePanelLayout.choicesBandHeight(
                    measuredRowHeights: heights,
                    contentViewportHeight: grown.contentViewportRect.height
                )
                #expect(abs(bandH - natural) < 1.0 || bandH >= natural - 0.5)
                let band = DialoguePanelLayout.choicesBandRect(
                    contentViewport: grown.contentViewportRect,
                    choicesBandHeight: bandH
                )
                let frames = DialoguePanelLayout.choiceRowFrames(band: band, rowHeights: heights)
                #expect(frames.count == 3)
                #expect(DialoguePanelLayout.choiceFramesAreNonOverlapping(frames))
                #expect(
                    DialoguePanelLayout.choiceFramesFitInBand(frames, band: band),
                    "Frames overflow band at aspect \(aspect); last.minY=\(frames.last?.minY ?? 0) band.minY=\(band.minY)"
                )
                for frame in frames {
                    #expect(frame.minY >= grown.contentViewportRect.minY - 0.5)
                }
                // Document the skeptic scenario: base often cannot hold natural without growth.
                if natural > baseMaxBand + 0.5 {
                    #expect(grown.panelRect.height > base.panelRect.height + 0.5)
                }
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

            let bar = DialoguePanelLayout.bodyScrollbarRect(
                fullScrollbarRect: layout.scrollbarRect,
                bodyViewport: body
            )
            #expect(abs(bar.minY - body.minY) < 0.01)
            #expect(abs(bar.height - body.height) < 0.01)
            #expect(bar.maxY <= content.maxY + 0.01)
            #expect(bar.minY >= choices.maxY - 0.01)
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

    @Test func presenterUsesFixedChoicesBandOutsideScrollContent() throws {
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
        // Choices must not be children of the scrolling root.
        #expect(source.contains("panelRoot.addChild(choicesRoot)"))
        #expect(!source.contains("scrollContentRoot.addChild(choicesRoot)"))
        // Multi-line measure must use CoreText path, not crushed scale factors.
        #expect(source.contains("DialogueTextMetrics.choiceRowHeight"))
        #expect(!source.contains("scaledHeights"))
        #expect(!source.contains(" * scale"))
        #expect(source.contains("dialogueScrollbar.isHidden"))
    }

    @Test func scrollbarSitsInContentWellClearOfRightFrameOrnament() {
        for size in representativeSizes {
            let layout = DialoguePanelLayout.layout(for: size)
            #expect(layout.scrollbarClearsTrailingFrameChrome, "Scrollbar overlaps frame chrome for \(size)")
            // Entire bar is on the black well, not only the text column.
            #expect(layout.contentWellRect.contains(layout.scrollbarRect.insetBy(dx: 1, dy: 1)))
            // Leave the right ornament band empty of controls.
            let trailingChrome = max(
                DialoguePanelLayout.minimumTrailingChrome,
                layout.panelRect.width * DialoguePanelLayout.trailingChromeFraction
            )
            let ornamentBand = CGRect(
                x: layout.panelRect.maxX - trailingChrome,
                y: layout.panelRect.minY,
                width: trailingChrome,
                height: layout.panelRect.height
            )
            #expect(!layout.scrollbarRect.intersects(ornamentBand.insetBy(dx: 0.5, dy: 0)))
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
        #expect(source.contains("geometry.bodyTextMaxWidth") || source.contains("panelLayout.bodyTextMaxWidth"))
        #expect(source.contains("panelLayout.choiceTextMaxWidth") || source.contains("geometry.choiceTextMaxWidth"))
        #expect(source.contains("contentMask.path = CGPath(rect:"))
        #expect(source.contains("bodyViewport") || source.contains("applySplitContentRegions"))
        #expect(!source.contains("panelRect.maxX - 176"), "Old fixed scrollbar inset must be gone")
    }

    @Test func presenterKeepsPortraitAndScrollbarAboveFrameOverlay() throws {
        // Frame sits above body text for rail clipping, but portrait/scrollbar must be higher.
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let presenterURL = root
            .appendingPathComponent("RainShadow Shared/UI/CaseIntroductionPresenter.swift")
        let source = try String(contentsOf: presenterURL, encoding: .utf8)

        func zPosition(for assignmentPrefix: String) -> Int? {
            // Match lines like `portrait.zPosition = 33` / `frameOverlay.zPosition = 10`.
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
        let scrollbarZ = try #require(zPosition(for: "dialogueScrollbar.zPosition"))

        #expect(frameZ > contentZ, "Frame must cover overflowing body text")
        #expect(portraitZ > frameZ, "Portrait must not sit under the left frame rail")
        #expect(scrollbarZ > frameZ, "Scrollbar must not sit under the right frame rail")
    }

    @Test func basePanelUsesCompactHeightContract() {
        #expect(DialoguePanelLayout.panelHeightCap < DialoguePanelLayout.legacyPanelHeightCap)
        #expect(DialoguePanelLayout.panelHeightFraction < DialoguePanelLayout.legacyPanelHeightFraction)
        #expect(DialoguePanelLayout.legacyPanelHeightCap > DialoguePanelLayout.originalPanelHeightCap)
        for size in representativeSizes {
            let layout = DialoguePanelLayout.layout(for: size)
            #expect(
                layout.panelRect.height
                    == min(
                        DialoguePanelLayout.panelHeightCap,
                        size.height * DialoguePanelLayout.panelHeightFraction
                    )
            )
        }
    }

    @Test func panelWidthIsCappedForSceneVisibility() {
        #expect(DialoguePanelLayout.panelWidthCap < DialoguePanelLayout.legacyPanelWidthCap)
        #expect(DialoguePanelLayout.horizontalMarginFraction > DialoguePanelLayout.legacyHorizontalMarginFraction)
        #expect(DialoguePanelLayout.horizontalMarginMin >= DialoguePanelLayout.legacyHorizontalMarginMin)

        for size in representativeSizes {
            let layout = DialoguePanelLayout.layout(for: size)
            #expect(layout.panelRect.width == DialoguePanelLayout.panelWidth(for: size))
            #expect(layout.bodyTextMaxWidth > 100)
            // Compact width stays at or under the prior ultra-wide ceiling.
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
        #expect(speaker < DialoguePanelLayout.Typography.legacySpeakerFontSize)
        #expect(speaker >= 17)
        #expect(choice == body)
        #expect(DialoguePanelLayout.Typography.caseTitleFontSize > body)
    }

    @Test func presenterUsesSharedTypographyAndClearsGeneratedFrameUnderlay() throws {
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
        #expect(source.contains("applyUnderlayStyle(usesGeneratedFrame:"))
        #expect(source.contains("panel.isHidden = true"))
        #expect(source.contains("innerPanel.isHidden = true"))
        #expect(source.contains("panelShadow.isHidden = true"))
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
            // Scrollbar column + the empty gutter to its left must sit on black (no floor peek).
            #expect(layout.contentWellRect.contains(layout.scrollbarRect.insetBy(dx: 1, dy: 1)))
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
        #expect(DialoguePanelLayout.panelChoicesOffsetY < DialoguePanelLayout.panelRestOffsetY)
        #expect(DialoguePanelLayout.panelPresentationOffsetY(hasChoices: false) == DialoguePanelLayout.panelRestOffsetY)
        #expect(DialoguePanelLayout.panelPresentationOffsetY(hasChoices: true) == DialoguePanelLayout.panelChoicesOffsetY)
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
        let frames = DialoguePanelLayout.choiceRowFrames(band: snug.choices, rowHeights: rowHeights)
        #expect(DialoguePanelLayout.choiceFramesFitInBand(frames, band: snug.choices))
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
        // Outer plates still hidden with generated frame; well is separate.
        #expect(source.contains("panel.isHidden = true"))
        #expect(source.contains("contentWell.isHidden = false"))
        #expect(source.contains("layoutCommandControl(panelRootOffsetY:"))
        #expect(source.contains("DialoguePanelLayout.commandHitRect"))
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
        #expect(restHit.midX == 0)

        // Center is the pure under-panel formula (no float-up over the frame).
        let expectedRestCenter = restPanelBottom
            - DialoguePanelLayout.commandGapBelowPanel
            - DialoguePanelLayout.commandHeight / 2
        #expect(abs(restHit.midY - expectedRestCenter) < 0.001)
    }
}
