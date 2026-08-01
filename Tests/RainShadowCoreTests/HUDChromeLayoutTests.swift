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
        CGSize(width: 834, height: 1_194),
        CGSize(width: 1_600, height: 1_400),
        CGSize(width: 2_048, height: 1_152)
    ]

    // MARK: - Left rail

    @Test func leftRailKeepsEntirePaintedTexture() {
        #expect(
            HUDChromeLayout.LeftRail.plateContentRect
                == CGRect(x: 0, y: 0, width: 1, height: 1),
            "Cropping the source texture flattens the painted top and bottom caps"
        )
    }

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
        let measuredCenters = HUDChromeLayout.LeftRail.wellCenterFractionsFromTop
        #expect(measuredCenters.count == HUDChromeLayout.LeftRail.wellCount)
        // Measured art is not equal-spaced; bottom wells sit lower than (i+0.5)/N.
        #expect(measuredCenters[11] > 0.92)
        #expect(measuredCenters[0] < 0.09)

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
            let plateH = layout.plateSize.height
            let plateTop = plateH / 2

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
                // Icons must not overflow the painted circular recess (~54% of plate width).
                #expect(icon.width <= layout.plateSize.width * 0.56 + 0.5)
                // Centers match measured fractions (from top of plate).
                let expectedY = plateTop - measuredCenters[index] * plateH
                #expect(abs(well.midY - expectedY) < 0.5, "Well \(index) Y off measured art at \(size)")
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

    @Test func leftRailPlateStaysInsetFromViewLeftEdge() {
        let inset = HUDChromeLayout.LeftRail.leftInset
        #expect(inset >= 8)
        for size in representativeSizes {
            let layout = HUDChromeLayout.leftRailLayout(for: size)
            let viewLeft = -size.width / 2
            let frame = layout.plateFrame
            #expect(
                frame.minX >= viewLeft + inset - 0.001,
                "Left rail left edge \(frame.minX) not inset by \(inset) at \(size)"
            )
            #expect(frame.maxX < size.width / 2)
            let clearance = HUDChromeLayout.leftRailClearance(for: size)
            #expect(clearance >= inset + layout.railWidth + 10 - 0.001)
            #expect(
                HUDChromeLayout.leftRailFullyOnScreen(for: size),
                "Left rail not fully on screen at \(size)"
            )
        }
    }

    @Test func leftRailPlateFrameMatchesCenterAndSize() {
        for size in representativeSizes {
            let layout = HUDChromeLayout.leftRailLayout(for: size)
            let frame = layout.plateFrame
            #expect(abs(frame.midX - layout.plateCenter.x) < 0.001)
            #expect(abs(frame.midY - layout.plateCenter.y) < 0.001)
            #expect(abs(frame.width - layout.plateSize.width) < 0.001)
            #expect(abs(frame.height - layout.plateSize.height) < 0.001)
            // Acceptance: full painted plate stays inside the viewport AABB.
            let halfW = size.width / 2
            let halfH = size.height / 2
            #expect(frame.minX >= -halfW - 0.001)
            #expect(frame.maxX <= halfW + 0.001)
            #expect(frame.minY >= -halfH - 0.001)
            #expect(frame.maxY <= halfH + 0.001)
            // Never flush-left (would clip the outer metal rim).
            #expect(frame.minX > -halfW + 0.5)
        }
    }

    @Test func rightRailStaysFullyOnScreenAlongsideLeftRail() {
        for size in representativeSizes {
            #expect(HUDChromeLayout.leftRailFullyOnScreen(for: size))
            #expect(
                HUDChromeLayout.rightRailFullyOnScreen(for: size),
                "Right portrait rail off-screen at \(size)"
            )
            let left = HUDChromeLayout.leftRailLayout(for: size).plateFrame
            let right = HUDChromeLayout.rightRailPlateFrame(for: size)
            // Rails must not occupy the same half of the view.
            #expect(left.maxX < 0 || right.minX > 0 || left.maxX < right.minX)
        }
    }

    @Test func actionBarAndPortraitBarSourceUseHUDChromeLayout() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let action = try String(
            contentsOf: root.appendingPathComponent("RainShadow Shared/UI/ActionBarNode.swift"),
            encoding: .utf8
        )
        let portrait = try String(
            contentsOf: root.appendingPathComponent("RainShadow Shared/UI/PortraitBarNode.swift"),
            encoding: .utf8
        )
        #expect(action.contains("HUDChromeLayout.leftRailLayout"))
        #expect(portrait.contains("HUDChromeLayout.rightRailLayout"))
        #expect(action.contains("position = geometry.plateCenter"))
    }

    @Test func baseSceneParentsHUDUnderCameraWithIdentityScale() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let base = try String(
            contentsOf: root.appendingPathComponent("RainShadow Shared/Core/Scene/BaseGameScene.swift"),
            encoding: .utf8
        )
        #expect(base.contains("gameCamera.addChild(hudRoot)"))
        #expect(base.contains("syncSizeFromViewIfNeeded"))
        #expect(base.contains("hudRoot.setScale(1)"))
        // Must not world-scale HUD by the play camera (maps ±size/2 past the view edge).
        #expect(!base.contains("hudRoot.setScale(scale)"))
        #expect(!base.contains("hudRoot.position = gameCamera.position"))
    }
}
