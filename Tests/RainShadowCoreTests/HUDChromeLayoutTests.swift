import CoreGraphics
import Foundation
import Testing
@testable import RainShadowCore

/// Fit/stretch contracts for left rail, right rail, and dialogue frame chrome.
struct HUDChromeLayoutTests {
    private let representativeSizes: [CGSize] = [
        CGSize(width: 800, height: 600),
        CGSize(width: 844, height: 390),
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

    // MARK: - Compact loot panel

    @Test func lootPanelKeepsFiveToOneAspectAndClearsBothHUDRails() {
        #expect(HUDChromeLayout.LootContainerPanel.aspectWidthOverHeight == 5)

        for size in representativeSizes {
            let layout = HUDChromeLayout.lootContainerPanelLayout(for: size)
            let panel = layout.panelRect
            let playMinX = -size.width / 2 + HUDChromeLayout.leftRailClearance(for: size)
            let playMaxX = size.width / 2 - HUDChromeLayout.rightRailClearance(for: size)

            #expect(
                abs(panel.width / panel.height - HUDChromeLayout.LootContainerPanel.aspectWidthOverHeight) < 0.001,
                "Loot panel lost its 5:1 aspect at \(size)"
            )
            #expect(panel.width <= HUDChromeLayout.LootContainerPanel.maxWidth + 0.001)
            #expect(
                panel.minX >= playMinX + HUDChromeLayout.LootContainerPanel.horizontalMargin - 0.001,
                "Loot panel overlaps the left HUD rail at \(size)"
            )
            #expect(
                panel.maxX <= playMaxX - HUDChromeLayout.LootContainerPanel.horizontalMargin + 0.001,
                "Loot panel overlaps the right HUD rail at \(size)"
            )
            #expect(panel.minY >= -size.height / 2 + HUDChromeLayout.LootContainerPanel.bottomInset - 0.001)
            #expect(panel.maxY <= size.height / 2 + 0.001)
        }
    }

    @Test func lootPanelFiveZonesStayContainedAndOrderedLeftToRight() {
        for size in representativeSizes {
            let layout = HUDChromeLayout.lootContainerPanelLayout(for: size)
            let zones = [
                layout.sourceIdentityRect,
                layout.sourceViewportRect,
                layout.carryRect,
                layout.bagViewportRect,
                layout.walletWellRect
            ]

            for zone in zones {
                #expect(
                    layout.panelRect.contains(zone.insetBy(dx: 0.001, dy: 0.001)),
                    "Loot zone \(zone) escapes panel \(layout.panelRect) at \(size)"
                )
            }

            for index in 1..<zones.count {
                #expect(
                    zones[index - 1].maxX <= zones[index].minX + 0.001,
                    "Loot zones \(index - 1) and \(index) overlap at \(size)"
                )
            }
        }
    }

    @Test func lootPanelChildrenStayInsideTheirSemanticZones() {
        for size in representativeSizes {
            let layout = HUDChromeLayout.lootContainerPanelLayout(for: size)

            let sourceIdentityChildren = [
                layout.sourcePropArtRect,
                layout.takeAllHitRect,
                layout.takeAllArtRect
            ]
            let sourceViewportChildren = [
                layout.sourcePreviousPageHitRect,
                layout.sourcePreviousPageArtRect,
                layout.sourceNextPageHitRect,
                layout.sourceNextPageArtRect
            ] + layout.sourceSlotHitRects + layout.sourceSlotArtRects
            let carryChildren = [
                layout.caseBagArtRect,
                layout.carriedWeightRect,
                layout.maximumWeightRect
            ]
            let bagViewportChildren = [
                layout.bagPreviousRowHitRect,
                layout.bagPreviousRowArtRect,
                layout.bagNextRowHitRect,
                layout.bagNextRowArtRect
            ] + layout.bagSlotHitRects + layout.bagSlotArtRects
            let walletChildren = [
                layout.walletRect,
                layout.walletCoinArtRect,
                layout.walletValueRect
            ]

            for rect in sourceIdentityChildren {
                #expect(layout.sourceIdentityRect.contains(rect))
            }
            for rect in sourceViewportChildren {
                #expect(layout.sourceViewportRect.contains(rect))
            }
            for rect in carryChildren {
                #expect(layout.carryRect.contains(rect))
            }
            for rect in bagViewportChildren {
                #expect(layout.bagViewportRect.contains(rect))
            }
            for rect in walletChildren {
                #expect(layout.walletWellRect.contains(rect))
            }

            #expect(layout.takeAllHitRect.contains(layout.takeAllArtRect))
            #expect(layout.sourcePreviousPageHitRect.contains(layout.sourcePreviousPageArtRect))
            #expect(layout.sourceNextPageHitRect.contains(layout.sourceNextPageArtRect))
            #expect(layout.bagPreviousRowHitRect.contains(layout.bagPreviousRowArtRect))
            #expect(layout.bagNextRowHitRect.contains(layout.bagNextRowArtRect))
        }
    }

    /// The recessed field inside the plate's painted metal frame.
    private func lootWell(of panel: CGRect) -> CGRect {
        let panelType = HUDChromeLayout.LootContainerPanel.self
        return CGRect(
            x: panel.minX + panel.width * panelType.wellSideInsetFraction,
            y: panel.minY + panel.height * panelType.wellBottomInsetFraction,
            width: panel.width * (1 - panelType.wellSideInsetFraction * 2),
            height: panel.height
                * (1 - panelType.wellTopInsetFraction - panelType.wellBottomInsetFraction)
        )
    }

    @Test func lootGemAndPageArrowsKeepClassicStripProportions() {
        for size in representativeSizes {
            let layout = HUDChromeLayout.lootContainerPanelLayout(for: size)
            let sourceSlot = layout.sourceSlotArtRects[0].width
            let bagSlot = layout.bagSlotArtRects[0].width
            let gemFraction = HUDChromeLayout.LootContainerPanel.takeAllArtToSlotFraction
            let arrowFraction = HUDChromeLayout.LootContainerPanel.pageArrowToSlotFraction
            let slotFraction = HUDChromeLayout.LootContainerPanel.slotToWellHeightFraction
            let minimum = HUDChromeLayout.LootContainerPanel.minimumHitExtent
            let wellHeight = lootWell(of: layout.panelRect).height

            // The grid never outgrows the reference slot-to-well ratio; only the
            // 44pt touch floor may push past it, on viewports too small to obey both.
            for slot in [sourceSlot, bagSlot] {
                #expect(
                    slot <= wellHeight * slotFraction + 0.001 || slot == minimum,
                    "Slot outgrew \(slotFraction) of the well at \(size)"
                )
            }

            #expect(
                abs(layout.takeAllArtRect.width - sourceSlot * gemFraction) < 0.001,
                "Take-all gem is not \(gemFraction) of a transfer slot at \(size)"
            )
            #expect(layout.takeAllArtRect.width == layout.takeAllArtRect.height)

            // Both arrow columns track their own grid unless the touch floor wins.
            for (arrow, slot) in [
                (layout.sourceNextPageArtRect, sourceSlot),
                (layout.sourcePreviousPageArtRect, sourceSlot),
                (layout.bagNextRowArtRect, bagSlot),
                (layout.bagPreviousRowArtRect, bagSlot)
            ] {
                #expect(
                    abs(arrow.width - slot * arrowFraction) < 0.001 || arrow.width == minimum,
                    "Page arrow is neither \(arrowFraction) of a slot nor the touch floor at \(size)"
                )
                #expect(arrow.width == arrow.height)
            }

            // The gem and the down arrow share the lower slot row's baseline.
            let sourceRowBottom = layout.sourceSlotArtRects[3].minY
            let bagRowBottom = layout.bagSlotArtRects[2].minY
            #expect(abs(layout.takeAllArtRect.minY - sourceRowBottom) < 0.001)
            #expect(abs(layout.sourceNextPageArtRect.minY - sourceRowBottom) < 0.001)
            #expect(abs(layout.bagNextRowArtRect.minY - bagRowBottom) < 0.001)

            // The up arrows mirror it against the upper row's top edge.
            #expect(abs(layout.sourcePreviousPageArtRect.maxY - layout.sourceSlotArtRects[0].maxY) < 0.001)
            #expect(abs(layout.bagPreviousRowArtRect.maxY - layout.bagSlotArtRects[0].maxY) < 0.001)

            // The gem is centred under the container prop, not tucked to a corner.
            #expect(abs(layout.takeAllArtRect.midX - layout.sourceIdentityRect.midX) < 0.001)
        }

        // On a viewport wide enough that neither the zone width nor the touch floor
        // binds, the grid reaches the reference ratio instead of stalling short.
        let wide = HUDChromeLayout.lootContainerPanelLayout(for: CGSize(width: 1_920, height: 1_080))
        let reference = lootWell(of: wide.panelRect).height
            * HUDChromeLayout.LootContainerPanel.slotToWellHeightFraction
        #expect(abs(wide.sourceSlotArtRects[0].width - reference) < 0.001)
        #expect(abs(wide.bagSlotArtRects[0].width - reference) < 0.001)
    }

    /// The painted plate's frame is not layout space: nothing the panel draws may
    /// ride up onto it, which is what made the lower row and the down arrow spill.
    @Test func lootPanelChildrenStayInsideThePaintedWell() {
        for size in representativeSizes {
            let layout = HUDChromeLayout.lootContainerPanelLayout(for: size)
            let well = lootWell(of: layout.panelRect)

            let drawn = [
                layout.sourcePropArtRect,
                layout.takeAllArtRect,
                layout.takeAllHitRect,
                layout.sourcePreviousPageArtRect,
                layout.sourceNextPageArtRect,
                layout.caseBagArtRect,
                layout.carriedWeightRect,
                layout.maximumWeightRect,
                layout.bagPreviousRowArtRect,
                layout.bagNextRowArtRect,
                layout.walletCoinArtRect,
                layout.walletValueRect
            ] + layout.sourceSlotArtRects + layout.bagSlotArtRects

            for rect in drawn {
                // The 44pt touch floor may still overflow a well too short to hold
                // two rows of it; nothing else is allowed to.
                let isTouchFloored = rect.height <= HUDChromeLayout.LootContainerPanel.minimumHitExtent
                    && well.height < HUDChromeLayout.LootContainerPanel.minimumHitExtent * 2
                #expect(
                    well.insetBy(dx: -0.001, dy: -0.001).contains(rect) || isTouchFloored,
                    "\(rect) escapes the painted well \(well) at \(size)"
                )
            }
        }
    }

    @Test func lootPanelSourceAndBagUseThreeByTwoAndTwoByTwoGrids() {
        #expect(HUDChromeLayout.LootContainerPanel.slotsPerPage == 6)
        #expect(HUDChromeLayout.LootContainerPanel.bagSlotsPerRow == 2)
        #expect(HUDChromeLayout.LootContainerPanel.bagVisibleRowCount == 2)
        #expect(HUDChromeLayout.LootContainerPanel.bagSlotsPerViewport == 4)

        for size in representativeSizes {
            let layout = HUDChromeLayout.lootContainerPanelLayout(for: size)
            #expect(layout.sourceSlotHitRects.count == 6)
            #expect(layout.sourceSlotArtRects.count == 6)
            #expect(layout.bagSlotHitRects.count == 4)
            #expect(layout.bagSlotArtRects.count == 4)

            let sourceX = Set(layout.sourceSlotHitRects.map { Int(($0.midX * 1_000).rounded()) })
            let sourceY = Set(layout.sourceSlotHitRects.map { Int(($0.midY * 1_000).rounded()) })
            #expect(sourceX.count == 3, "Source grid does not have three columns at \(size)")
            #expect(sourceY.count == 2, "Source grid does not have two rows at \(size)")

            let bagX = Set(layout.bagSlotArtRects.map { Int(($0.midX * 1_000).rounded()) })
            let bagY = Set(layout.bagSlotArtRects.map { Int(($0.midY * 1_000).rounded()) })
            #expect(bagX.count == 2, "Bag preview does not have two columns at \(size)")
            #expect(bagY.count == 2, "Bag preview does not have two rows at \(size)")

            for index in layout.sourceSlotHitRects.indices {
                #expect(layout.sourceSlotHitRects[index].contains(layout.sourceSlotArtRects[index]))
            }
            for index in layout.bagSlotHitRects.indices {
                #expect(layout.bagSlotHitRects[index].contains(layout.bagSlotArtRects[index]))
            }
        }
    }

    @Test func lootPanelInteractiveRectsMeetMinimumHitExtent() {
        let minimum = HUDChromeLayout.LootContainerPanel.minimumHitExtent
        #expect(minimum >= 44)

        for size in representativeSizes {
            let layout = HUDChromeLayout.lootContainerPanelLayout(for: size)
            let hitRects = [
                layout.takeAllHitRect,
                layout.sourcePreviousPageHitRect,
                layout.sourceNextPageHitRect,
                layout.bagPreviousRowHitRect,
                layout.bagNextRowHitRect
            ] + layout.sourceSlotHitRects + layout.bagSlotHitRects

            for rect in hitRects {
                #expect(rect.width >= minimum - 0.001, "Loot hit width is undersized at \(size)")
                #expect(rect.height >= minimum - 0.001, "Loot hit height is undersized at \(size)")
            }
        }
    }

    @Test func lootPanelSourcePagingScrollsOneThreeItemRowAtATime() {
        let empty = HUDChromeLayout.lootContainerPage(itemCount: 0, requestedPage: -4)
        #expect(empty.pageIndex == 0)
        #expect(empty.pageCount == 1)
        #expect(empty.visibleRange == 0..<0)
        #expect(!empty.canGoPrevious)
        #expect(!empty.canGoNext)

        let exactPage = HUDChromeLayout.lootContainerPage(itemCount: 6, requestedPage: 1)
        #expect(exactPage.pageIndex == 0)
        #expect(exactPage.pageCount == 1)
        #expect(exactPage.visibleRange == 0..<6)

        let first = HUDChromeLayout.lootContainerPage(itemCount: 7, requestedPage: -1)
        #expect(first.pageIndex == 0)
        #expect(first.pageCount == 2)
        #expect(first.visibleRange == 0..<6)
        #expect(!first.canGoPrevious)
        #expect(first.canGoNext)

        let second = HUDChromeLayout.lootContainerPage(itemCount: 7, requestedPage: 1)
        #expect(second.pageIndex == 1)
        #expect(second.visibleRange == 3..<7)
        #expect(second.canGoPrevious)
        #expect(!second.canGoNext)

        let clampedLast = HUDChromeLayout.lootContainerPage(itemCount: 13, requestedPage: 99)
        #expect(clampedLast.pageIndex == 3)
        #expect(clampedLast.pageCount == 4)
        #expect(clampedLast.visibleRange == 9..<13)
        #expect(clampedLast.canGoPrevious)
        #expect(!clampedLast.canGoNext)
    }

    @Test func lootPanelBagViewportScrollsOneTwoItemRowAtATime() {
        let empty = HUDChromeLayout.lootContainerBagViewport(itemCount: 0, requestedRow: -4)
        #expect(empty.rowIndex == 0)
        #expect(empty.rowCount == 1)
        #expect(empty.visibleRange == 0..<0)
        #expect(!empty.canGoPrevious)
        #expect(!empty.canGoNext)

        let exactViewport = HUDChromeLayout.lootContainerBagViewport(itemCount: 4, requestedRow: 2)
        #expect(exactViewport.rowIndex == 0)
        #expect(exactViewport.rowCount == 2)
        #expect(exactViewport.visibleRange == 0..<4)
        #expect(!exactViewport.canGoPrevious)
        #expect(!exactViewport.canGoNext)

        let middle = HUDChromeLayout.lootContainerBagViewport(itemCount: 7, requestedRow: 1)
        #expect(middle.rowIndex == 1)
        #expect(middle.rowCount == 4)
        #expect(middle.visibleRange == 2..<6)
        #expect(middle.canGoPrevious)
        #expect(middle.canGoNext)

        let last = HUDChromeLayout.lootContainerBagViewport(itemCount: 7, requestedRow: 99)
        #expect(last.rowIndex == 2)
        #expect(last.visibleRange == 4..<7)
        #expect(last.canGoPrevious)
        #expect(!last.canGoNext)
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
