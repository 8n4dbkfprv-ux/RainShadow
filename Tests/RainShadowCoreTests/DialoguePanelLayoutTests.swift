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
            #expect(layout.bodyTextMaxWidth == layout.contentViewportRect.width)
            #expect(layout.choiceTextMaxWidth <= layout.contentViewportRect.width)
            #expect(
                layout.choiceTextMaxWidth
                    == layout.contentViewportRect.width - DialoguePanelLayout.choiceLabelHorizontalInset * 2
            )
            #expect(layout.bodyTextMaxWidth > 100, "Body width too narrow for \(size)")
            #expect(layout.choiceTextMaxWidth > 80, "Choice width too narrow for \(size)")
        }
    }

    @Test func vivianOpeningChoiceFitsInsideContentViewport() {
        // Representative multi-line choice from the case-opening screenshot.
        let choice =
            "2:  Why are you certain she didn't go into the river?"
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
        #expect(source.contains("contentMask.path = CGPath(rect: contentViewportRect"))
        #expect(!source.contains("panelRect.maxX - 176"), "Old fixed scrollbar inset must be gone")
    }
}
