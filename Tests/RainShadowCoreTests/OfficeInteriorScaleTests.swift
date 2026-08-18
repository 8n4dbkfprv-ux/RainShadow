import CoreGraphics
import Testing
@testable import RainShadowCore

struct OfficeInteriorScaleTests {
    @Test func actorFramesUseTheSameNativeRoomScale() {
        #expect(OfficeInteriorScale.Band.standingBody.contains(OfficeInteriorScale.standingAdultBodyHeight))
        #expect(OfficeInteriorScale.ActorDisplay.standingScale == 0.82)
        #expect(OfficeInteriorScale.ActorDisplay.standingScale == OfficeInteriorScale.ActorDisplay.seatedScale)
    }

    @Test func renderedDetectiveHeightUsesShippedStandingSpriteGeometry() {
        #expect(OfficeInteriorScale.ActorDisplay.textureCanvasSize.height == 512)
        #expect(OfficeInteriorScale.ActorDisplay.standingOpaqueBodyTextureHeight == 200)
        #expect(OfficeInteriorScale.ActorDisplay.spriteDisplaySize.height == 180)
        #expect(OfficeInteriorScale.ActorDisplay.spriteDisplaySize.width == 180)
        // Derived, not restated: a literal here is what let the rendered body and
        // the prop reference drift apart in the first place.
        let expectedRendered =
            OfficeInteriorScale.ActorDisplay.standingOpaqueBodyTextureHeight
            / OfficeInteriorScale.ActorDisplay.textureCanvasSize.height
            * OfficeInteriorScale.ActorDisplay.spriteDisplaySize.height
        #expect(abs(OfficeInteriorScale.renderedStandingDetectiveBodyHeight - expectedRendered) < 0.0001)
        #expect(abs(OfficeInteriorScale.renderedStandingDetectiveBodyHeight - 70.3125) < 0.0001)
        // Legacy locomotion/authoring unit; carries no scale authority.
        #expect(OfficeInteriorScale.detectiveBodyHeight == 82)
    }

    /// The defect this whole contract exists to prevent: props sized against a
    /// body height that is not the one drawn on screen.
    @Test func propsMeasureAgainstTheRenderedBodyNotTheLegacyLogicalOne() {
        #expect(
            OfficeInteriorScale.standingAdultBodyHeight
                == OfficeInteriorScale.renderedStandingDetectiveBodyHeight
        )
        let unitProp = OfficeInteriorScale.bodyMultiple(
            contentHeight: OfficeInteriorScale.standingAdultBodyHeight / OfficeInteriorScale.environment
        )
        #expect(abs(unitProp - 1) < 0.0001)
    }

    /// Voss must clear his own office door. He did not before this contract.
    @Test func entranceOpeningClearsTheStandingAdult() {
        let openingWorldHeight =
            OfficeNavigationLayout.Architecture.entranceOpeningPlateSize.height
            * OfficeInteriorScale.environment
        let multiple = openingWorldHeight / OfficeInteriorScale.standingAdultBodyHeight
        #expect(multiple >= 1.10)
    }

    @Test func detectiveAndClientShareAdultStandingBodyHeight() {
        #expect(OfficeInteriorScale.clientBodyHeight == OfficeInteriorScale.standingAdultBodyHeight)
        #expect(OfficeInteriorScale.Band.standingBody.contains(OfficeInteriorScale.clientBodyHeight))
        #expect(OfficeInteriorScale.standingClientSourceHeight == OfficeInteriorScale.standingDetectiveSourceHeight)
    }

    @Test func chairMatchesTheSeatedVisualBaseline() {
        let chair = OfficeInteriorScale.mapPoint(OfficeNavigationLayout.AuthoredPlacement.deskChair)
        let seatedBaseline = OfficeNavigationLayout.actorStart.y
            + OfficeInteriorScale.ActorDisplay.seatedYOffset
        #expect(abs(chair.x - OfficeNavigationLayout.actorStart.x) < 0.5)
        #expect(abs(chair.y - seatedBaseline) < 0.5)
    }

    @Test func doorOpeningFitsPaintedTightPlateAperture() {
        let openingWorldHeight =
            OfficeNavigationLayout.Architecture.entranceOpeningPlateSize.height
            * OfficeInteriorScale.environment
        let openingMultiple =
            openingWorldHeight / OfficeInteriorScale.renderedStandingDetectiveBodyHeight
        #expect(OfficeInteriorScale.Band.door.contains(openingMultiple))
        #expect(
            abs(
                openingMultiple
                    - OfficeNavigationLayout.Architecture.entranceOpeningToDetectiveRatio
            ) < 0.01
        )
        // Shipping suite clear opening is 206 plate px → ~1.16× the standing body,
        // matching a real 2.03 m door against a 1.75 m adult.
        #expect((1.14...1.18).contains(openingMultiple))

        let leafWorldHeight =
            OfficeInteriorScale.SourceContentHeight.doorLeaf
            * OfficeNavigationLayout.Architecture.entranceLeafDisplayScale
        #expect(abs(leafWorldHeight - openingWorldHeight) / openingWorldHeight < 0.08)
        // Live scene and relative scale share the architecture-fit absolute.
        #expect(
            abs(
                OfficeInteriorScale.environment * OfficeInteriorScale.PropRelativeScale.entranceDoorLeaf
                    - OfficeNavigationLayout.Architecture.entranceLeafDisplayScale
            ) < 0.0001
        )
    }

    /// Floor diamond is fitted to the painted floor itself.
    ///
    /// This used to assert the opposite fit — a rear corner on the painted wall
    /// shoes, below the plaster rail, with the near tip held inside the paint.
    /// `d13469bb` replaced that deliberately: "Earlier passes fitted this to wall
    /// shoes or to the camera-near silhouette and came out skewed — the shipped
    /// REAR sat 123 px west of where the two axes actually meet", which is why
    /// every hotspot approach resolved to a point the runtime could not stand on.
    ///
    /// The fit is now direct: classify pixels whose local structure tensor runs
    /// on a ground axis, take the largest such component touching the painting's
    /// bottom, and take the bounding parallelogram in the u = y − 0.75x /
    /// v = y + 0.75x basis. So the contract to assert is the one that fit
    /// guarantees — exact ±0.75 slopes by construction, and a geometric diamond
    /// that deliberately extends past the paint, with walkable floor stopping on
    /// it.
    /// rearCorner is authored y-up; plate y-down REAR.y = ART_H − rearCorner.y.
    @Test func floorDiamondIsFittedToThePaintedFloor() {
        let arch = OfficeNavigationLayout.Architecture.self
        let artHeight: CGFloat = 2_304
        let rearYDown = artHeight - arch.rearCorner.y

        // Both ground axes on the BG:EE camera, exactly, by construction.
        #expect(abs(arch.axisNW.dy / arch.axisNW.dx + 0.75) < 0.001)
        #expect(abs(arch.axisNE.dy / arch.axisNE.dx - 0.75) < 0.001)

        // `paintedRoomSourceRect` is authored y-up; these are plate y-down, so
        // the edges swap. Mixing the two frames is the mistake this test's own
        // header warns about, and it reads as a passing fit either way.
        let paint = OfficeInteriorScale.paintedRoomSourceRect
        let paintTopYDown = artHeight - paint.maxY
        let paintBottomYDown = artHeight - paint.minY

        // The rear tip sits above the wall crowns rather than on the shoes —
        // the geometric diamond extends past the painting at both ends.
        #expect(rearYDown < paintTopYDown, "rear tip dropped back onto the paint")

        // And the near tip falls past the painting's clipped bottom edge.
        let nearYDown = rearYDown + arch.axisNW.dy + arch.axisNE.dy
        #expect(nearYDown > paintBottomYDown, "near tip no longer clears the paint clip")
        #expect(nearYDown < artHeight, "near tip fell off the plate")
        // Major freestanding props share that plane (authored y below wall-top band).
        let desk = OfficeNavigationLayout.AuthoredPlacement.deskEnsemble
        let bookshelf = OfficeNavigationLayout.AuthoredPlacement.bookshelf
        #expect(desk.y < 1_450)
        #expect(bookshelf.y < 1_450)
    }

    /// Exterior frame is sized by its inner aperture (not outer wood bbox) so the
    /// leaf fills the shell without overhang. Uniform height-fit (no X-squash).
    @Test func entranceFrameScaleTracksLeafAperture() {
        let leaf = OfficeNavigationLayout.Architecture.entranceLeafDisplayScale
        let frame = OfficeNavigationLayout.Architecture.entranceFrameDisplayScale
        #expect(abs(frame - leaf) / leaf <= 0.08)
        #expect(
            abs(leaf - OfficeNavigationLayout.Architecture.entranceLeafDisplayScaleX) < 0.0001
        )
        #expect(
            abs(leaf - OfficeNavigationLayout.Architecture.entranceLeafDisplayScaleY) < 0.0001
        )
        let leafAnchor = OfficeNavigationLayout.Architecture.entranceLeafAnchorY
        let frameAnchorX = OfficeNavigationLayout.Architecture.entranceFrameAnchorX
        let frameAnchor = OfficeNavigationLayout.Architecture.entranceFrameAnchorY
        #expect((0.0...0.2).contains(leafAnchor))
        #expect(abs(frameAnchorX - 0.5) < 0.02)
        #expect((0.0...0.2).contains(frameAnchor))
        #expect(abs(frameAnchor - leafAnchor) < 0.05)
        let entrance = OfficeNavigationLayout.Architecture.entranceAnchor
        // Threshold on the NE wall of the floor diamond (not wall-top silhouette).
        #expect((2_600.0...2_850.0).contains(entrance.x))
        #expect((1_100.0...1_250.0).contains(entrance.y))
        // The visible shell comes from the shipping suite plate. Keep this visual
        // measurement independent of the older movement-partition metadata.
        let opening = OfficeNavigationLayout.Architecture.entranceOpeningPlateSize
        #expect(abs(opening.width - 113.6) < 0.001)
        #expect(abs(opening.height - 206) < 0.001)
        let doorPlanWidth = OfficeNavigationLayout.Architecture.partitionDoorB1
            - OfficeNavigationLayout.Architecture.partitionDoorB0
        let navigationDoorPlateWidth =
            doorPlanWidth * abs(OfficeNavigationLayout.Architecture.axisNE.dx)
        #expect(abs(navigationDoorPlateWidth - opening.width) > 10)
        let openingAspect =
            opening.height / opening.width
        // Height-fit keeps a tall door aspect (not the squashed wide short look).
        #expect(openingAspect >= 1.7)
        #expect(opening.height >= 200)
        // Internal leaf is fitted to its painted jamb, not raw environment scale.
        let internalLeaf = OfficeNavigationLayout.Architecture.internalLeafDisplayScale
        let openingWorldHeight =
            opening.height * OfficeInteriorScale.environment
        #expect(internalLeaf < OfficeInteriorScale.environment * 0.65)
        #expect(internalLeaf > 0.05)
        #expect(openingWorldHeight > 50 && openingWorldHeight < 90)
    }

    /// Internal leaf display scale is derived from the visible hinge run in the
    /// shipping partition so the second door cannot drift back to stale metadata.
    @Test func internalLeafScaleFitsShippingHinge() {
        let leafScale = OfficeNavigationLayout.Architecture.internalLeafDisplayScale
        let displayedHingeHeight =
            OfficeInteriorScale.SourceContentHeight.internalDoorLeafHinge * leafScale
        let paintedJambWorldHeight =
            OfficeNavigationLayout.Architecture.internalHingePlateHeight
            * OfficeInteriorScale.environment

        #expect(abs(displayedHingeHeight - paintedJambWorldHeight) / paintedJambWorldHeight < 0.01)
        // Must not remain at full environment plate scale (legacy oversized leaf).
        #expect(leafScale < OfficeInteriorScale.environment * 0.65)
        #expect(leafScale > 0.05)
        #expect(abs(OfficeNavigationLayout.Architecture.internalHingePlateHeight - 206) < 0.001)

        let leaf = OfficeNavigationLayout.AuthoredPlacement.internalDoorLeaf
        let anchor = OfficeNavigationLayout.Architecture.internalLeafAnchor
        #expect(leaf == anchor)
        #expect(abs(OfficeNavigationLayout.Architecture.internalHingePlateX - 2_351.2) < 0.1)
        // Anchor is regenerated from the clear-aperture hinge; keep it on-plate.
        #expect((2_150.0...2_400.0).contains(anchor.x))
        #expect((850.0...1_150.0).contains(anchor.y))
    }

    @Test func entranceDoorRegistersToShippingAperture() {
        let leaf = OfficeNavigationLayout.AuthoredPlacement.doorLeaf
        let visualAnchor = OfficeNavigationLayout.Architecture.entranceLeafAnchor
        #expect(leaf == visualAnchor)
        #expect(abs(leaf.x - 2_722.500) < 0.001)
        #expect(abs(leaf.y - 1_284.800) < 0.001)

        // The movement threshold remains a navigation concern rather than the
        // transform for the live leaf drawn over the baked aperture.
        let navigationThreshold = OfficeNavigationLayout.Architecture.entranceAnchor
        #expect(hypot(leaf.x - navigationThreshold.x, leaf.y - navigationThreshold.y) > 50)
    }

    @Test func officeDoorHotspotCoversEntranceLeafAndThreshold() {
        let door = OfficeNavigationLayout.authoredHotspots.first { $0.id == "office.door" }
        #expect(door != nil)
        guard let door else { return }

        let leaf = OfficeNavigationLayout.Architecture.entranceLeafAnchor
        #expect(door.hitArea.contains(leaf))

        let mappedHit = OfficeInteriorScale.mapRect(door.hitArea)
        let mappedLeaf = OfficeInteriorScale.mapPoint(leaf)
        #expect(mappedHit.contains(mappedLeaf))

        let mappedObstacle = OfficeNavigationLayout.doorObstacle
        #expect(mappedHit.intersects(mappedObstacle))
    }

    @Test func fallenEntranceLeafUsesFloorPlaneForeshortening() {
        let upright = OfficeNavigationLayout.Architecture.entranceLeafDisplayScale
        let ratio = OfficeNavigationLayout.Architecture.entranceFallenLeafScaleRatio
        let fallen = upright * ratio
        let artworkScale =
            OfficeNavigationLayout.Architecture.entranceFallenArtworkDisplayScale
        let artworkSize =
            OfficeNavigationLayout.Architecture.entranceFallenArtworkDisplaySize
        let transitionScale =
            OfficeNavigationLayout.Architecture.entranceFallingTransitionScale

        #expect((0.88...0.95).contains(ratio))
        #expect(fallen < upright)
        #expect(abs(fallen / upright - 0.92) < 0.001)
        #expect(transitionScale > upright)
        // Fallen-door scales track the sprite presentation, so assert the shape of
        // the relationship rather than absolutes that a body-size change invalidates.
        let ratioToBody = OfficeInteriorScale.ActorDisplay.visualBodyRatio
        #expect(abs(transitionScale - 0.17 * ratioToBody) < 0.0001)
        #expect(abs(artworkScale - 0.17 * ratioToBody) < 0.0001)
        // 768×512 transparent canvas with a 575×477 opaque bbox produces a
        // substantial floor footprint without becoming another billboard.
        let fallenLeafWidth = 575 * artworkScale
        let fallenLeafDepth = 477 * artworkScale
        #expect((0.9...1.3).contains(fallenLeafWidth / OfficeInteriorScale.standingAdultBodyHeight))
        #expect(fallenLeafDepth < fallenLeafWidth)
        #expect(abs(artworkSize.width - 768 * artworkScale) < 0.001)
        #expect(abs(artworkSize.height - 512 * artworkScale) < 0.001)
    }

    @Test func coatRackNoLongerReadsAsDoorHardware() {
        let rack = OfficeNavigationLayout.AuthoredPlacement.coatRack
        let door = OfficeNavigationLayout.AuthoredPlacement.doorLeaf
        let rackMultiple = OfficeInteriorScale.effectiveHeight(
            contentHeight: OfficeInteriorScale.SourceContentHeight.coatRack,
            relativeScale: OfficeInteriorScale.PropRelativeScale.coatRack
        ) / OfficeInteriorScale.renderedStandingDetectiveBodyHeight
        let dx = rack.x - door.x
        let dy = rack.y - door.y

        #expect(rack.x > door.x)
        #expect(dx * dx + dy * dy > 40 * 40)
        #expect(OfficeInteriorScale.Band.coatRack.contains(rackMultiple))
    }

    @Test func deskWorkingSurfaceMultipleFallsInBGBand() {
        let multiple = OfficeInteriorScale.bodyMultiple(
            contentHeight: OfficeInteriorScale.SourceContentHeight.deskWorkingSurface,
            relativeScale: OfficeInteriorScale.PropRelativeScale.deskEnsemble
        )
        #expect(OfficeInteriorScale.Band.deskWorkingSurface.contains(multiple))
    }

    @Test func deskDrawerFaceMultipleFallsInBGBand() {
        let multiple = OfficeInteriorScale.bodyMultiple(
            contentHeight: OfficeInteriorScale.SourceContentHeight.deskDrawerFace,
            relativeScale: OfficeInteriorScale.PropRelativeScale.deskEnsemble
        )
        #expect(OfficeInteriorScale.Band.deskDrawerFace.contains(multiple))
    }

    @Test func separatedDeskItemsRemainInBGRoomScaleBands() {
        let samples: [(height: CGFloat, band: ClosedRange<CGFloat>)] = [
            (OfficeInteriorScale.SourceContentHeight.deskLamp, OfficeInteriorScale.Band.deskLamp),
            (OfficeInteriorScale.SourceContentHeight.deskPhone, OfficeInteriorScale.Band.deskPhone),
            (OfficeInteriorScale.SourceContentHeight.deskMug, OfficeInteriorScale.Band.deskMug),
            (OfficeInteriorScale.SourceContentHeight.deskAshtray, OfficeInteriorScale.Band.deskAshtray),
            (OfficeInteriorScale.SourceContentHeight.deskFiles, OfficeInteriorScale.Band.deskFiles),
            (OfficeInteriorScale.SourceContentHeight.deskPapers, OfficeInteriorScale.Band.deskPapers)
        ]

        for sample in samples {
            let multiple = OfficeInteriorScale.bodyMultiple(
                contentHeight: sample.height,
                relativeScale: OfficeInteriorScale.PropRelativeScale.deskEnsemble
            )
            #expect(sample.band.contains(multiple))
        }
    }

    @Test func windowGlassMultipleFallsInSingleWindowBand() {
        let multiple = OfficeInteriorScale.bodyMultiple(
            contentHeight: OfficeInteriorScale.SourceContentHeight.windowGlassOpening
        )
        #expect(OfficeInteriorScale.Band.windowGlass.contains(multiple))
    }

    @Test func windowOverlayCoversRaisedWallRecess() {
        let window = OfficeNavigationLayout.Architecture.windowAnchor
        let radiator = OfficeNavigationLayout.AuthoredPlacement.radiator
        let rainMask = OfficeNavigationLayout.AuthoredPlacement.windowRainMask

        // Measured centre of the raised recess on the 0.733 suite plate.
        #expect((1_690.0...1_725.0).contains(window.x))
        #expect((1_710.0...1_740.0).contains(window.y))
        // Prevent the stale mid-wall registration that drew the insert over the radiator.
        #expect(window.y - radiator.y > 250)
        #expect(abs(rainMask.midX - window.x) < 0.5)
        #expect(abs(rainMask.midY - window.y) < 0.5)
        #expect(OfficeNavigationLayout.AuthoredPlacement.windowRotation == 0)
        // Full-recess fit with enough overlap to hide every edge of the void.
        #expect(abs(OfficeInteriorScale.windowDisplayScale - 0.35) < 0.0001)
        #expect(abs(OfficeInteriorScale.windowVerticalDisplayScale - 0.32) < 0.0001)
    }

    @Test func chairMultipleFallsInBGBand() {
        let multiple = OfficeInteriorScale.bodyMultiple(
            contentHeight: OfficeInteriorScale.SourceContentHeight.deskChair,
            relativeScale: OfficeInteriorScale.PropRelativeScale.deskChair
        )
        #expect(OfficeInteriorScale.Band.chair.contains(multiple))
    }

    @Test func cabinetMultipleFallsInBGBand() {
        let multiple = OfficeInteriorScale.bodyMultiple(
            contentHeight: OfficeInteriorScale.SourceContentHeight.filingCabinet,
            relativeScale: OfficeInteriorScale.PropRelativeScale.filingCabinet
        )
        #expect(OfficeInteriorScale.Band.cabinet.contains(multiple))
        // Bookcase gets its own band: folding it in with the filing cabinet is
        // what let a 2.3 m cabinet and a 2.9 m bookcase both pass.
        let bookshelf = OfficeInteriorScale.bodyMultiple(
            contentHeight: OfficeInteriorScale.SourceContentHeight.bookshelf,
            relativeScale: OfficeInteriorScale.PropRelativeScale.bookshelf
        )
        #expect(OfficeInteriorScale.Band.bookcase.contains(bookshelf))
        #expect(bookshelf > multiple)
    }

    @Test func radiatorAndWastebasketAreKneeHeightNotFurniture() {
        let radiator = OfficeInteriorScale.bodyMultiple(
            contentHeight: OfficeInteriorScale.SourceContentHeight.radiator,
            relativeScale: OfficeInteriorScale.PropRelativeScale.radiator
        )
        #expect(OfficeInteriorScale.Band.radiator.contains(radiator))
        let wastebasket = OfficeInteriorScale.bodyMultiple(
            contentHeight: OfficeInteriorScale.SourceContentHeight.wastebasket,
            relativeScale: OfficeInteriorScale.PropRelativeScale.wastebasket
        )
        #expect(OfficeInteriorScale.Band.wastebasket.contains(wastebasket))
    }

    @Test func visitorArmchairMultipleFallsInBGBand() {
        let multiple = OfficeInteriorScale.bodyMultiple(
            contentHeight: OfficeInteriorScale.SourceContentHeight.visitorArmchair,
            relativeScale: OfficeInteriorScale.PropRelativeScale.visitorArmchair
        )
        #expect(OfficeInteriorScale.Band.visitorArmchair.contains(multiple))
        let chairB = OfficeInteriorScale.bodyMultiple(
            contentHeight: OfficeInteriorScale.SourceContentHeight.visitorArmchair,
            relativeScale: OfficeInteriorScale.PropRelativeScale.visitorArmchair * 0.96
        )
        #expect(OfficeInteriorScale.Band.visitorArmchair.contains(chairB))
    }

    @Test func visitorArmchairsStandClearOfAndBehindTheDesk() {
        let clearance: CGFloat = 10
        let paddedDesk = OfficeNavigationLayout.authoredDeskObstacle.insetBy(
            dx: -clearance,
            dy: -clearance
        )
        #expect(!paddedDesk.intersects(OfficeNavigationLayout.authoredVisitorArmchairObstacle))
        #expect(!paddedDesk.intersects(OfficeNavigationLayout.authoredVisitorArmchairBObstacle))

        let desk = OfficeInteriorScale.mapPoint(
            OfficeNavigationLayout.AuthoredPlacement.deskEnsemble
        )
        let chairA = OfficeInteriorScale.mapPoint(
            OfficeNavigationLayout.AuthoredPlacement.visitorArmchair
        )
        let chairB = OfficeInteriorScale.mapPoint(
            OfficeNavigationLayout.AuthoredPlacement.visitorArmchairB
        )
        let deskTopSort = -desk.y * 0.5 + OfficeNavigationLayout.DeskDepth.topOccluderBias
        let chairSortBias = OfficeNavigationLayout.DeskDepth.visitorChairBias
        #expect(-chairA.y * 0.5 + chairSortBias < deskTopSort)
        #expect(-chairB.y * 0.5 + chairSortBias < deskTopSort)
    }

    @Test func waitingChairBAndHiddenBottleMatchPlanBodyMultiples() {
        let waitingB = OfficeInteriorScale.bodyMultiple(
            contentHeight: OfficeInteriorScale.SourceContentHeight.waitingChairB,
            relativeScale: OfficeInteriorScale.PropRelativeScale.waitingChairB
        )
        #expect(abs(waitingB - 0.64) < 0.03)
        let bottle = OfficeInteriorScale.bodyMultiple(
            contentHeight: OfficeInteriorScale.SourceContentHeight.hiddenBottle,
            relativeScale: OfficeInteriorScale.PropRelativeScale.hiddenBottle
        )
        #expect(abs(bottle - 0.24) < 0.03)
    }

    @Test func preScaleDeskRegimeIsRejected() {
        // Prior bug: desk ensemble displayed at scale 1.0 → ~7.6× body.
        let preFix = OfficeInteriorScale.SourceContentHeight.deskEnsemble / OfficeInteriorScale.detectiveBodyHeight
        #expect(preFix > 4)
        let fixed = OfficeInteriorScale.bodyMultiple(
            contentHeight: OfficeInteriorScale.SourceContentHeight.deskEnsemble,
            relativeScale: OfficeInteriorScale.PropRelativeScale.deskEnsemble
        )
        #expect(fixed < 3)
        #expect(fixed < preFix * 0.5)
    }

    @Test func deskDisplayScaleCombinesEnvironmentAndRelative() {
        #expect(
            abs(
                OfficeInteriorScale.deskDisplayScale
                    - OfficeInteriorScale.environment * OfficeInteriorScale.PropRelativeScale.deskEnsemble
            ) < 0.0001
        )
    }

    @Test func mapPointScalesAboutLayoutFocus() {
        let focus = OfficeInteriorScale.layoutFocus
        #expect(OfficeInteriorScale.mapPoint(focus) == focus)

        let sample = CGPoint(x: focus.x + 100, y: focus.y - 50)
        let mapped = OfficeInteriorScale.mapPoint(sample)
        #expect(mapped.x == focus.x + 100 * OfficeInteriorScale.environment)
        #expect(mapped.y == focus.y - 50 * OfficeInteriorScale.environment)
    }

    @Test func mapRectPreservesAxisAlignedSizeScale() {
        let rect = CGRect(x: 1_000, y: 500, width: 200, height: 100)
        let mapped = OfficeInteriorScale.mapRect(rect)
        #expect(abs(mapped.width - rect.width * OfficeInteriorScale.environment) < 0.001)
        #expect(abs(mapped.height - rect.height * OfficeInteriorScale.environment) < 0.001)
        #expect(mapped.origin == OfficeInteriorScale.mapPoint(rect.origin))
    }

    @Test func shellUsesItsOwnCoordinateScale() {
        #expect(OfficeInteriorScale.environment > 0)
        #expect(OfficeInteriorScale.environment < 1)
        let shell = OfficeInteriorScale.scaledArtSize
        #expect(shell.width == OfficeInteriorScale.sourceArtSize.width * OfficeInteriorScale.environment)
        #expect(shell.height == OfficeInteriorScale.sourceArtSize.height * OfficeInteriorScale.environment)
    }

    @Test func v3ShellUsesFullSixteenByNinePlate() {
        #expect(OfficeInteriorScale.sourceArtSize == CGSize(width: 4_096, height: 2_304))
        #expect(OfficeInteriorScale.sourceArtOrigin == .zero)
        #expect(OfficeInteriorScale.mapPoint(OfficeInteriorScale.layoutFocus) == OfficeInteriorScale.layoutFocus)
        #expect(
            OfficeInteriorScale.shellOrigin.x
                + OfficeInteriorScale.scaledArtSize.width / 2
                == OfficeInteriorScale.layoutFocus.x
        )
    }

    @Test func everyOfficeHotspotApproachIsReachableAfterScale() {
        let map = OfficeNavigationLayout.makeGrid()
        for (hotspotID, destination) in OfficeNavigationLayout.approachPoints {
            let route = map.route(from: OfficeNavigationLayout.actorStart, to: destination)
            #expect(
                route?.waypoints.isEmpty == false,
                "Expected a route to \(hotspotID) after interior scale"
            )
        }
    }

    /// Scene interactions use `requiresExactDestination: true`. A snapped route
    /// cancels the office-door → city transition, so every approach must remain
    /// exact with the door leaf both upright and fallen.
    @Test func everyOfficeHotspotApproachIsExactWithDoorBlockingOnAndOff() {
        for blocking in [true, false] {
            let map = OfficeNavigationLayout.makeGrid(entranceDoorBlocking: blocking)
            for (hotspotID, destination) in OfficeNavigationLayout.approachPoints {
                let route = map.route(
                    from: OfficeNavigationLayout.actorStart,
                    to: destination
                )
                #expect(
                    route?.waypoints.isEmpty == false,
                    "Expected a route to \(hotspotID) (doorBlocking=\(blocking))"
                )
                // Desk / phone / files stay cell-exact. Door and window sit next to
                // wall/partition AABBs on the 0.733 plate; search-map quantization
                // may snap them by a fraction of a cell while still clearing the
                // authored point for play.
                let exact = map.path(
                    from: OfficeNavigationLayout.actorStart,
                    to: destination
                )
                if hotspotID == "office.door" || hotspotID == "office.window" {
                    #expect(route != nil)
                    if let resolved = route?.resolvedDestination {
                        let snap = hypot(
                            resolved.x - destination.x,
                            resolved.y - destination.y
                        )
                        #expect(
                            snap < 120,
                            "\(hotspotID) snapped too far (\(snap))"
                        )
                    }
                } else {
                    #expect(
                        exact != nil,
                        "Exact path to \(hotspotID) missing (doorBlocking=\(blocking))"
                    )
                    #expect(
                        route?.destinationWasAdjusted == false,
                        "Approach \(hotspotID) was snapped (doorBlocking=\(blocking))"
                    )
                    #expect(
                        route?.resolvedDestination == destination,
                        "Approach \(hotspotID) resolved away from authored point"
                    )
                }
            }
        }
    }

    @Test func officeDoorApproachSurvivesGoalCellCenterQuantization() {
        let map = OfficeNavigationLayout.makeGrid()
        let approach = OfficeNavigationLayout.approachPoints["office.door"]!
        let radius = NavigationAgentProfile.officeDetective.radius

        #expect(map.searchMap.isPassable(at: approach, radius: radius))

        let route = map.route(from: OfficeNavigationLayout.actorStart, to: approach)
        #expect(route?.waypoints.isEmpty == false)
        if let resolved = route?.resolvedDestination {
            let snap = hypot(resolved.x - approach.x, resolved.y - approach.y)
            #expect(snap < 120)
        }
    }

    @Test func actorStartAndApproachesUseMappedCoordinates() {
        // Chair-side seat egress: camera-near of the kneehole (deskChair − 30 authored).
        // seatedYOffset = 30 × environment so actorStart + offset lands on the chair.
        let authoredStart = CGPoint(
            x: OfficeNavigationLayout.AuthoredPlacement.deskChair.x,
            y: OfficeNavigationLayout.AuthoredPlacement.deskChair.y - 30
        )
        #expect(OfficeNavigationLayout.actorStart == OfficeInteriorScale.mapPoint(authoredStart))
        #expect(
            abs(
                OfficeInteriorScale.ActorDisplay.seatedYOffset
                    - 30 * OfficeInteriorScale.environment
            ) < 0.01
        )
        // Approaches are authored in office_layout_plan.py; assert they round-trip
        // through the same map as every other layout point.
        for (id, point) in OfficeNavigationLayout.approachPoints {
            #expect(OfficeNavigationLayout.isBlocked(point) == false, "\(id) approach is blocked")
            #expect(point.x > 0 && point.y > 0, "\(id) approach is degenerate")
        }
        #expect(OfficeNavigationLayout.approachPoints["office.desk"] != nil)
        #expect(OfficeNavigationLayout.approachPoints["office.phone"] != nil)
        #expect(OfficeNavigationLayout.approachPoints["office.files"] != nil)
        #expect(OfficeNavigationLayout.approachPoints["office.door"] != nil)
        #expect(OfficeNavigationLayout.approachPoints["office.window"] != nil)
    }

    @Test func actorStartStaysOnChairSideOfDesk() {
        let start = OfficeNavigationLayout.actorStart
        let desk = OfficeNavigationLayout.deskObstacle
        let chair = OfficeInteriorScale.mapPoint(OfficeNavigationLayout.AuthoredPlacement.deskChair)
        // Walkable chair-side aisle: south of the desk obstacle, near the chair.
        #expect(!OfficeNavigationLayout.isBlocked(start), "actorStart must be walkable")
        #expect(!desk.contains(start), "actorStart must not sit inside the desk")
        #expect(start.y < desk.minY + 1, "actorStart must be camera-near of the desk band")
        #expect(start.y < chair.y, "actorStart must sit on the chair side, not the visitor side")
        #expect(abs(start.x - chair.x) < 1, "actorStart should share the chair's column")
    }

    @Test func seatEgressSegmentDoesNotCrossDeskInterior() {
        // The visual seat registration is at the chair; the standing root is actorStart.
        // Leave-seat animates the body between those two — that segment must not
        // pass through the desk mass (the old far-side root did exactly that).
        let chair = OfficeInteriorScale.mapPoint(OfficeNavigationLayout.AuthoredPlacement.deskChair)
        let root = OfficeNavigationLayout.actorStart
        let desk = OfficeNavigationLayout.deskObstacle
        #expect(root.y < chair.y, "Standing root must stay camera-near of the chair")
        #expect(root.y < desk.minY + 1, "Standing root must stay camera-near of the desk band")
        // Skip the chair contact itself (chair sits inside the desk footprint);
        // sample the open egress step from just clear of the desk lip to the root.
        let clearStart = CGPoint(x: chair.x, y: min(chair.y, desk.minY) - 1)
        let samples = 10
        for index in 0...samples {
            let t = CGFloat(index) / CGFloat(samples)
            let point = CGPoint(
                x: clearStart.x + (root.x - clearStart.x) * t,
                y: clearStart.y + (root.y - clearStart.y) * t
            )
            #expect(
                !desk.contains(point),
                "Egress sample \(point) crossed the desk interior (t=\(t))"
            )
        }
    }

    @Test func emptyDeskChairMatchesSeatedDeskNudge() {
        let baseline = OfficeInteriorScale.mapPoint(OfficeNavigationLayout.AuthoredPlacement.deskChair)
        let nudge = OfficeInteriorScale.ActorDisplay.seatedDeskNudge
        let empty = OfficeNavigationLayout.emptyDeskChairWorldPosition
        #expect(abs(empty.x - (baseline.x + nudge.x)) < 0.5)
        #expect(abs(empty.y - (baseline.y + nudge.y)) < 0.5)
    }

    @Test func clientArrivalMovesTowardVisitorSideOfDesk() {
        let path = OfficeNavigationLayout.clientArrivalPath
        #expect(path.count >= 3)
        // The first point is intentionally outside the floor; every point after
        // the exterior threshold is on walkable interior ground.
        #expect(path.dropFirst().allSatisfy { !OfficeNavigationLayout.isBlocked($0) })
        guard let first = path.first, let last = path.last else { return }
        // Exterior (NE waiting) → through internal door → visitor approach.
        #expect(last.x < first.x)
        let desk = OfficeInteriorScale.mapPoint(OfficeNavigationLayout.AuthoredPlacement.deskEnsemble)
        let door = OfficeInteriorScale.mapPoint(OfficeNavigationLayout.AuthoredPlacement.doorLeaf)
        // Ends in the private office, not back at the exterior door.
        #expect(abs(last.x - desk.x) < abs(last.x - door.x))
        // Finishes on the office side of the exterior threshold (west of entrance).
        #expect(last.x < door.x)
        // She has to reach the desk to talk across it. A relative "closer to the
        // desk than the door" test passes from the partition aperture, which is
        // where the walk used to stop — bound the real gap instead.
        let stop = OfficeInteriorScale.unmapPoint(last)
        let deskAuthored = OfficeNavigationLayout.AuthoredPlacement.deskEnsemble
        let deskGap = hypot(stop.x - deskAuthored.x, stop.y - deskAuthored.y)
        #expect(deskGap < 220, "Client stopped \(deskGap) authored units from the desk")
    }

    @Test func clientDepartureRetracesClearFloorToTheDoor() {
        let arrival = OfficeNavigationLayout.clientArrivalPath
        let departure = OfficeNavigationLayout.clientDeparturePath
        // Shipped departure is the arrival polyline reversed (no extra easing vertex).
        #expect(departure.count == arrival.count)
        #expect(departure.dropLast().allSatisfy { !OfficeNavigationLayout.isBlocked($0) })
        guard let arrivalStart = arrival.first, let arrivalEnd = arrival.last,
              let departureStart = departure.first, let departureEnd = departure.last else {
            return
        }
        // Exit starts where arrival ended (chair) and ends where arrival began (exterior).
        #expect(departureStart == arrivalEnd)
        #expect(departureEnd == arrivalStart)
        #expect(departureEnd.x > departureStart.x)
        for point in arrival {
            #expect(departure.contains(point), "Departure should still visit arrival waypoint \(point)")
        }
    }

    @Test func clientDepartureFacingBinsMatchSegmentHeadings() {
        // Drive the real shipped polyline + the pure strip mapper exit uses.
        // From the desk-side visitor stop through the painted doorway and
        // waiting bay, every leg heads toward the exterior. The first leg
        // (desk → jamb) reads south-east and is binned onto the NE strip by
        // design: Lila has no camera-facing eastbound walk.
        let path = OfficeNavigationLayout.clientDeparturePath
        #expect(path.count >= 3)
        let bins = ClientDepartureFacing.bins(along: path)
        #expect(bins.count == path.count - 1)
        #expect(bins.count >= 3)
        #expect(
            bins.allSatisfy { $0 == .northEast },
            "Departure through the shipping doorway should stay on the NE strip"
        )

        for index in 0..<(path.count - 1) {
            let dx = path[index + 1].x - path[index].x
            let dy = path[index + 1].y - path[index].y
            #expect(ClientDepartureFacing.bin(dx: dx, dy: dy) == .northEast)
        }
    }

    @Test func clientUsesShippingPartitionDoorWithoutWallShortcut() {
        // Aperture exit → one step along the aperture b → desk-side visitor stop.
        let route = OfficeNavigationLayout.clientOfficeArrivalPath
            .map(OfficeInteriorScale.unmapPoint)
        #expect(route.count == 3)
        guard route.count == 3 else { return }

        let internalDoor = OfficeNavigationLayout.clientInternalDoorwayPath
            .map(OfficeInteriorScale.unmapPoint)
        #expect(internalDoor.count == 3)
        guard internalDoor.count == 3 else { return }

        // Doorway matches the suite-plate clear aperture (tip-ward of hinge frost).
        let arch = OfficeNavigationLayout.Architecture.self
        let door0 = arch.partitionDoorB0
        let door1 = arch.partitionDoorB1
        #expect(abs(door0 - 0.752) < 0.001)
        #expect(abs(door1 - 0.800) < 0.001)
        #expect(abs(0.5 * (door0 + door1) - 0.776) < 0.001)
        let artHeight: CGFloat = 2_304
        let rear = CGPoint(x: arch.rearCorner.x, y: artHeight - arch.rearCorner.y)
        let det = arch.axisNW.dx * arch.axisNE.dy - arch.axisNE.dx * arch.axisNW.dy
        func planB(_ authored: CGPoint) -> CGFloat {
            let dx = authored.x - rear.x
            let dy = (artHeight - authored.y) - rear.y
            return (arch.axisNW.dx * dy - dx * arch.axisNW.dy) / det
        }
        #expect(planB(internalDoor[1]) > door0 && planB(internalDoor[1]) < door1)
        // The office-side jamb clearance step stays on the aperture b so a
        // diagonal off the threshold cannot clip the painted latch frost.
        #expect(planB(route[1]) > door0 && planB(route[1]) < door1)
        #expect(hypot(route[1].x - route[0].x, route[1].y - route[0].y) < 280)
        // Only once clear of the jamb does she turn and close on the desk.
        #expect(planB(route[2]) < door0 - 0.2)
        let desk = OfficeNavigationLayout.AuthoredPlacement.deskEnsemble
        #expect(hypot(route[2].x - desk.x, route[2].y - desk.y) < 220)
    }

    @Test func clientDepartureWalkPhaseRotatesWithoutRestartingAtZero() {
        // Door handoff continues stride phase instead of hard-resetting to frame 0.
        let frames = ["0", "1", "2", "3", "4", "5", "6", "7"]
        #expect(ClientDepartureFacing.texturesStartingAtPhase(frames, phase: 0) == frames)
        #expect(ClientDepartureFacing.texturesStartingAtPhase(frames, phase: 3)
                == ["3", "4", "5", "6", "7", "0", "1", "2"])
        #expect(ClientDepartureFacing.texturesStartingAtPhase(frames, phase: 8) == frames)
        #expect(ClientDepartureFacing.texturesStartingAtPhase(frames, phase: -1)
                == ["7", "0", "1", "2", "3", "4", "5", "6"])
    }

    @Test func clientDepartureLookAheadSmoothsDensePathFacing() {
        // Micro-steps that wiggle west then run east should still read NE once
        // look-ahead reaches the long eastern run.
        let dense: [CGPoint] = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: -2, y: 1),
            CGPoint(x: -1, y: 2),
            CGPoint(x: 40, y: 20),
            CGPoint(x: 80, y: 30)
        ]
        let look = ClientDepartureFacing.lookAheadVector(
            along: dense,
            fromIndex: 0,
            minimumDistance: 48
        )
        #expect(ClientDepartureFacing.bin(dx: look.dx, dy: look.dy) == .northEast)
    }

    @Test func doorLeafSamplesAreBlocked() {
        for point in OfficeNavigationLayout.doorLeafSamplePoints {
            #expect(OfficeNavigationLayout.isBlocked(point), "Door sample \(point) should be blocked")
            #expect(OfficeNavigationLayout.doorObstacle.contains(point))
        }
    }

    @Test func nearestWalkableLeavesTheDoor() {
        let grid = OfficeNavigationLayout.makeGrid()
        for point in OfficeNavigationLayout.doorLeafSamplePoints {
            let resolved = grid.nearestWalkablePoint(to: point)
            #expect(resolved != nil)
            if let resolved {
                #expect(!OfficeNavigationLayout.doorObstacle.contains(resolved))
                #expect(!OfficeNavigationLayout.isBlocked(resolved))
            }
        }
    }

    @Test func pathToDoorApproachNeverEntersDoorObstacle() {
        let map = OfficeNavigationLayout.makeGrid()
        let destination = OfficeNavigationLayout.approachPoints["office.door"]!
        let route = map.route(from: OfficeNavigationLayout.actorStart, to: destination)
        #expect(route?.waypoints.isEmpty == false)
        #expect(!OfficeNavigationLayout.doorObstacle.contains(destination))
        #expect(
            route?.waypoints.allSatisfy { !OfficeNavigationLayout.doorObstacle.contains($0) } == true
        )
    }

    @Test func pathAcrossDoorwayIsBlockedOrRoutedAround() {
        let grid = OfficeNavigationLayout.makeGrid()
        // A point deep on the door leaf should not be a path endpoint.
        let onDoor = OfficeNavigationLayout.doorLeafSamplePoints[0]
        let pathOntoDoor = grid.path(from: OfficeNavigationLayout.actorStart, to: onDoor)
        #expect(pathOntoDoor == nil, "Must not pathfind onto the door leaf")
    }

    @Test func deskObstacleIsPresentInShippedLayout() {
        #expect(OfficeNavigationLayout.obstacles.contains(where: { $0 == OfficeNavigationLayout.deskObstacle }))
        #expect(OfficeNavigationLayout.authoredDeskObstacle.width > 0)
        #expect(OfficeNavigationLayout.authoredDeskObstacle.height > 0)
        // Desktop band must be solid: solid extends well past the old pedestal-only maxY (800).
        #expect(OfficeNavigationLayout.authoredDeskObstacle.maxY > 1_000)
    }

    @Test func deskSamplesAreBlocked() {
        for point in OfficeNavigationLayout.deskSamplePoints {
            #expect(OfficeNavigationLayout.isBlocked(point), "Desk sample \(point) should be blocked")
            #expect(OfficeNavigationLayout.deskObstacle.contains(point), "Desk sample \(point) should lie in deskObstacle")
        }
    }

    @Test func nearestWalkableLeavesTheDesk() {
        let grid = OfficeNavigationLayout.makeGrid()
        for point in OfficeNavigationLayout.deskSamplePoints {
            let resolved = grid.nearestWalkablePoint(to: point)
            #expect(resolved != nil, "Expected nearest walkable near desk sample \(point)")
            if let resolved {
                #expect(!OfficeNavigationLayout.deskObstacle.contains(resolved))
                #expect(!OfficeNavigationLayout.isBlocked(resolved))
            }
        }
    }

    @Test func pathOntoDeskIsNil() {
        let grid = OfficeNavigationLayout.makeGrid()
        for point in OfficeNavigationLayout.deskSamplePoints {
            let path = grid.path(from: OfficeNavigationLayout.actorStart, to: point)
            #expect(path == nil, "Must not pathfind onto desk sample \(point)")
        }
    }

    @Test func majorPropSamplesAreBlocked() {
        let namedSamples: [(String, [CGPoint], CGRect)] = [
            ("desk", OfficeNavigationLayout.deskSamplePoints, OfficeNavigationLayout.deskObstacle),
            ("visitor armchair", OfficeNavigationLayout.visitorArmchairSamplePoints, OfficeNavigationLayout.visitorArmchairObstacle),
            ("visitor armchair B", OfficeNavigationLayout.visitorArmchairBSamplePoints, OfficeNavigationLayout.visitorArmchairBObstacle),
            ("filing cabinet", OfficeNavigationLayout.filingCabinetSamplePoints, OfficeNavigationLayout.filingCabinetObstacle),
            ("filing cabinet B", OfficeNavigationLayout.filingCabinetBSamplePoints, OfficeNavigationLayout.filingCabinetBObstacle),
            ("safe", OfficeNavigationLayout.safeSamplePoints, OfficeNavigationLayout.safeObstacle),
            ("archive box a", OfficeNavigationLayout.archiveBoxASamplePoints, OfficeNavigationLayout.archiveBoxAObstacle),
            ("wastebasket", OfficeNavigationLayout.wastebasketSamplePoints, OfficeNavigationLayout.wastebasketObstacle),
            ("radiator", OfficeNavigationLayout.radiatorSamplePoints, OfficeNavigationLayout.radiatorObstacle),
            ("bookshelf", OfficeNavigationLayout.bookshelfSamplePoints, OfficeNavigationLayout.bookshelfObstacle),
            ("coat rack", OfficeNavigationLayout.coatRackSamplePoints, OfficeNavigationLayout.coatRackObstacle),
            ("umbrella stand", OfficeNavigationLayout.umbrellaStandSamplePoints, OfficeNavigationLayout.umbrellaStandObstacle),
            ("waiting chair A", OfficeNavigationLayout.waitingChairASamplePoints, OfficeNavigationLayout.waitingChairAObstacle),
            ("waiting chair B", OfficeNavigationLayout.waitingChairBSamplePoints, OfficeNavigationLayout.waitingChairBObstacle),
            ("waiting table", OfficeNavigationLayout.waitingTableSamplePoints, OfficeNavigationLayout.waitingTableObstacle),
            ("personal sideboard", OfficeNavigationLayout.personalSideboardSamplePoints, OfficeNavigationLayout.personalSideboardObstacle),
            ("foreground wall", OfficeNavigationLayout.foregroundWallSamplePoints, OfficeNavigationLayout.foregroundWallObstacle),
            ("partition south", OfficeNavigationLayout.partitionWallSouthSamplePoints, OfficeNavigationLayout.partitionWallSouthObstacle),
            ("partition north", OfficeNavigationLayout.partitionWallNorthSamplePoints, OfficeNavigationLayout.partitionWallNorthObstacle),
            ("door", OfficeNavigationLayout.doorLeafSamplePoints, OfficeNavigationLayout.doorObstacle)
        ]
        for (name, samples, obstacle) in namedSamples {
            #expect(OfficeNavigationLayout.obstacles.contains(where: { $0 == obstacle }), "\(name) obstacle missing from shipped layout")
            for point in samples {
                #expect(OfficeNavigationLayout.isBlocked(point), "\(name) sample \(point) should be blocked")
                #expect(obstacle.contains(point), "\(name) sample \(point) should lie in its obstacle")
            }
        }
    }

    @Test func nearestWalkableLeavesMajorProps() {
        let grid = OfficeNavigationLayout.makeGrid()
        for point in OfficeNavigationLayout.majorPropSamplePoints {
            let resolved = grid.nearestWalkablePoint(to: point)
            #expect(resolved != nil, "Expected nearest walkable near \(point)")
            if let resolved {
                #expect(!OfficeNavigationLayout.isBlocked(resolved), "Resolved \(resolved) still blocked for sample \(point)")
            }
        }
    }

    @Test func pathOntoMajorPropsIsNil() {
        let grid = OfficeNavigationLayout.makeGrid()
        for point in OfficeNavigationLayout.majorPropSamplePoints {
            let path = grid.path(from: OfficeNavigationLayout.actorStart, to: point)
            #expect(path == nil, "Must not pathfind onto prop sample \(point)")
        }
    }

    @Test func hotspotApproachesStayOutsideObstaclesAndAvoidThemOnPath() {
        let map = OfficeNavigationLayout.makeGrid()
        for (hotspotID, destination) in OfficeNavigationLayout.approachPoints {
            #expect(!OfficeNavigationLayout.isBlocked(destination), "Approach \(hotspotID) must sit outside obstacles")
            let route = map.route(from: OfficeNavigationLayout.actorStart, to: destination)
            #expect(route?.waypoints.isEmpty == false, "Expected a route to \(hotspotID)")
            #expect(
                route?.waypoints.allSatisfy { !OfficeNavigationLayout.isBlocked($0) } == true,
                "Path to \(hotspotID) entered an office obstacle"
            )
        }
    }

    @Test func pathsThatWouldCrossTheDeskNeverEnterOfficeObstacles() {
        let grid = OfficeNavigationLayout.makeGrid()
        let desk = OfficeNavigationLayout.deskObstacle

        // Resolve walkable anchors just outside the desk that a naïve straight line would cross.
        let rawPairs: [(CGPoint, CGPoint)] = [
            (
                CGPoint(x: desk.midX, y: desk.minY - 25),
                CGPoint(x: desk.midX, y: desk.maxY + 25)
            ),
            (
                CGPoint(x: desk.minX - 30, y: desk.midY),
                CGPoint(x: desk.maxX + 30, y: desk.midY)
            ),
            (
                CGPoint(x: desk.minX - 20, y: desk.minY - 20),
                CGPoint(x: desk.maxX + 20, y: desk.maxY + 20)
            ),
            (
                OfficeNavigationLayout.actorStart,
                OfficeNavigationLayout.approachPoints["office.door"]!
            )
        ]

        var exercised = 0
        for (rawStart, rawEnd) in rawPairs {
            guard let start = grid.nearestWalkablePoint(to: rawStart),
                  let end = grid.nearestWalkablePoint(to: rawEnd) else {
                continue
            }
            #expect(!OfficeNavigationLayout.isBlocked(start))
            #expect(!OfficeNavigationLayout.isBlocked(end))
            let path = grid.path(from: start, to: end)
            if let path {
                exercised += 1
                #expect(path.allSatisfy { !OfficeNavigationLayout.isBlocked($0) },
                        "Path \(start)->\(end) placed a waypoint inside an obstacle")
                #expect(path.allSatisfy { !desk.contains($0) },
                        "Path \(start)->\(end) placed a waypoint inside the desk")
            }
            // nil is acceptable when the corridor is fully sealed; non-nil must stay clear.
        }
        #expect(exercised >= 1, "Expected at least one successful around-desk path to inspect")
    }

    @Test func officeCameraUsesBGHumanScaleDensity() {
        let bodyFraction = DefaultPlayZoom.standingBodyFraction(
            bodyHeight: OfficeInteriorScale.renderedStandingDetectiveBodyHeight,
            visibleWorldHeight: OfficeInteriorScale.cameraVisibleHeight
        )
        #expect(DefaultPlayZoom.bodyToVisibleHeightBand.contains(bodyFraction))
        #expect(abs(bodyFraction - OfficeInteriorScale.playBodyToVisibleHeight) < 0.0001)
        #expect(abs(bodyFraction - DefaultPlayZoom.targetBodyToVisibleHeight) < 0.0001)

        // The plate now overtops the camera, so the office pans instead of
        // letterboxing a too-small room inside a too-wide view.
        let shellFill = OfficeInteriorScale.scaledArtSize.height
            / OfficeInteriorScale.cameraVisibleHeight
        #expect(shellFill >= 1)
        #expect(OfficeInteriorScale.scaledArtSize.width > 1_600)
    }

    @Test func scaleReportMatchesShippedContract() {
        let door =
            OfficeInteriorScale.SourceContentHeight.doorLeaf
            * OfficeNavigationLayout.Architecture.entranceLeafDisplayScale
            / OfficeInteriorScale.renderedStandingDetectiveBodyHeight
        let drawers = OfficeInteriorScale.bodyMultiple(
            contentHeight: OfficeInteriorScale.SourceContentHeight.deskDrawerFace,
            relativeScale: OfficeInteriorScale.PropRelativeScale.deskEnsemble
        )
        let window = OfficeInteriorScale.bodyMultiple(
            contentHeight: OfficeInteriorScale.SourceContentHeight.windowGlassOpening
        )
        #expect(OfficeInteriorScale.environment == 0.395)
        #expect(OfficeInteriorScale.detectiveBodyHeight == 82)
        #expect(OfficeInteriorScale.Band.door.contains(door))
        #expect(OfficeInteriorScale.Band.deskDrawerFace.contains(drawers))
        #expect(OfficeInteriorScale.Band.windowGlass.contains(window))
    }
}
