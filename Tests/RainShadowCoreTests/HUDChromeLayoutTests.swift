import CoreGraphics
import Foundation
import Testing
@testable import RainShadowCore

/// Fit/stretch contracts for left rail, right rail, and dialogue frame chrome.
struct HUDChromeLayoutTests {
    private let representativeSizes: [CGSize] = [
        CGSize(width: 800, height: 600),
        CGSize(width: 1_024, height: 768),
        CGSize(width: 1_280, height: 800),
        CGSize(width: 1_920, height: 1_080),
        CGSize(width: 834, height: 1_194)
    ]

    // MARK: - Left rail

    @Test func leftRailPlatePreservesArtAspect() {
        let artAspect = HUDChromeLayout.LeftRail.artAspectWidthOverHeight
        for size in representativeSizes {
            let layout = HUDChromeLayout.leftRailLayout(for: size)
            let drawn = layout.plateSize.width / layout.plateSize.height
            #expect(
                abs(drawn - artAspect) < 0.002,
                "Left rail aspect \(drawn) != art \(artAspect) at \(size)"
            )
            #expect(layout.plateSize.height <= size.height + 0.001)
            #expect(layout.plateSize.width >= 40)
        }
    }

    @Test func leftRailIconsSitInsideNonOverlappingWells() {
        for size in representativeSizes {
            let layout = HUDChromeLayout.leftRailLayout(for: size)
            #expect(layout.wellRects.count == HUDChromeLayout.LeftRail.wellCount)
            #expect(layout.iconRects.count == HUDChromeLayout.LeftRail.wellCount)

            let plateLocal = CGRect(
                x: -layout.plateSize.width / 2,
                y: -layout.plateSize.height / 2,
                width: layout.plateSize.width,
                height: layout.plateSize.height
            )

            for index in layout.wellRects.indices {
                let well = layout.wellRects[index]
                let icon = layout.iconRects[index]
                #expect(
                    plateLocal.contains(well.insetBy(dx: 0.5, dy: 0.5)),
                    "Well \(index) outside plate at \(size)"
                )
                #expect(
                    well.insetBy(dx: -0.5, dy: -0.5).contains(icon),
                    "Icon \(index) not inside well at \(size)"
                )
                // Square icons (no stretch).
                #expect(abs(icon.width - icon.height) < 0.01)
            }

            // Wells do not overlap each other.
            for i in 0..<layout.wellRects.count {
                for j in (i + 1)..<layout.wellRects.count {
                    #expect(
                        !layout.wellRects[i].intersects(layout.wellRects[j]),
                        "Wells \(i) and \(j) overlap at \(size)"
                    )
                }
            }
        }
    }

    @Test func leftRailDoesNotUseFullWindowNonUniformStretch() {
        // Historically plate width was fixed while height = window height (aspect drifted).
        for size in representativeSizes {
            let layout = HUDChromeLayout.leftRailLayout(for: size)
            let fullWindowAspect = layout.plateSize.width / size.height
            let artAspect = HUDChromeLayout.LeftRail.artAspectWidthOverHeight
            // Drawn plate must match art, not (fixedWidth / windowHeight).
            #expect(abs(layout.plateSize.width / layout.plateSize.height - artAspect) < 0.002)
            #expect(abs(fullWindowAspect - artAspect) > 0.001 || layout.plateSize.height >= size.height - 20)
        }
    }

    // MARK: - Right rail

    @Test func rightRailPortraitAndUtilitiesFitInPaintedWells() {
        for size in representativeSizes {
            let layout = HUDChromeLayout.rightRailLayout(for: size)
            let artAspect = HUDChromeLayout.RightRail.plateContentAspectHeightOverWidth
            let drawn = layout.plateSize.height / layout.plateSize.width
            #expect(abs(drawn - artAspect) < 0.01, "Right plate aspect \(drawn) at \(size)")

            #expect(
                layout.portraitWindowRect.contains(layout.portraitPhotoRect.insetBy(dx: 0.5, dy: 0.5)),
                "Portrait photo spills past window at \(size)"
            )
            #expect(layout.utilityWellRects.count == 3)
            #expect(layout.utilityIconRects.count == 3)

            let plateLocal = CGRect(
                x: -layout.plateSize.width / 2,
                y: -layout.plateSize.height / 2,
                width: layout.plateSize.width,
                height: layout.plateSize.height
            )
            for index in layout.utilityWellRects.indices {
                let well = layout.utilityWellRects[index]
                let icon = layout.utilityIconRects[index]
                #expect(plateLocal.contains(well.insetBy(dx: 0.5, dy: 0.5)))
                #expect(well.insetBy(dx: -0.5, dy: -0.5).contains(icon))
                #expect(abs(icon.width - icon.height) < 0.01)
            }
            for i in 0..<3 {
                for j in (i + 1)..<3 {
                    #expect(!layout.utilityWellRects[i].intersects(layout.utilityWellRects[j]))
                }
            }
        }
    }

    // MARK: - Dialogue frame

    @Test func dialoguePanelPreservesFrameArtAspect() {
        let artAspect = DialoguePanelLayout.frameArtAspectWidthOverHeight
        for size in representativeSizes {
            let layout = DialoguePanelLayout.layout(for: size)
            let drawn = layout.panelRect.width / layout.panelRect.height
            #expect(
                abs(drawn - artAspect) < 0.01,
                "Dialogue panel aspect \(drawn) != art \(artAspect) at \(size)"
            )
        }
    }

    @Test func dialoguePortraitPhotoSitsInsidePaintedWindow() {
        for size in representativeSizes {
            let layout = DialoguePanelLayout.layout(for: size)
            let window = layout.portraitRect
            let photo = DialoguePanelLayout.portraitPhotoRect(in: layout.panelRect)
            #expect(
                window.insetBy(dx: -0.5, dy: -0.5).contains(photo),
                "Dialogue portrait photo outside window at \(size)"
            )
            #expect(abs(photo.width - photo.height) < 0.01)
            // Photo must be strictly smaller than (or equal with inset) the window.
            #expect(photo.width <= window.width - DialoguePanelLayout.portraitInnerInset + 0.5)
            #expect(photo.height <= window.height - DialoguePanelLayout.portraitInnerInset + 0.5)
        }
    }

    @Test func aspectLockedPanelSizeFitsInsideMaxBox() {
        let cases: [(CGFloat, CGFloat)] = [
            (800, 280), (1_200, 400), (600, 200), (1_000, 500)
        ]
        for (maxW, maxH) in cases {
            let size = DialoguePanelLayout.aspectLockedPanelSize(maxWidth: maxW, maxHeight: maxH)
            #expect(size.width <= maxW + 0.01)
            #expect(size.height <= maxH + 0.01)
            let aspect = size.width / size.height
            #expect(abs(aspect - DialoguePanelLayout.frameArtAspectWidthOverHeight) < 0.01)
        }
    }

    @Test func actionBarAndPortraitBarSourceUseHUDChromeLayout() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let actionURL = root.appendingPathComponent("RainShadow Shared/UI/ActionBarNode.swift")
        let portraitURL = root.appendingPathComponent("RainShadow Shared/UI/PortraitBarNode.swift")
        let action = try String(contentsOf: actionURL, encoding: .utf8)
        let portrait = try String(contentsOf: portraitURL, encoding: .utf8)
        #expect(action.contains("HUDChromeLayout.leftRailLayout"))
        #expect(portrait.contains("HUDChromeLayout.rightRailLayout"))
        #expect(!action.contains("Stretch cropped plate across nearly the full window height"))
    }
}
