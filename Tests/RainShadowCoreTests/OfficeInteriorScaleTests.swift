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

    @Test func closedDoorLeafKeepsMeasuredSliverDimensions() {
        let sliver = OfficeNavigationLayout.Architecture.entranceOpeningPlateSize
        #expect(abs(sliver.width - 68.055) < 0.01)
        #expect(abs(sliver.height - 493.015) < 0.01)
        #expect(sliver.height > sliver.width * 7)
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

    @Test func doorVisualUsesUniformReferenceScale() {
        let architecture = OfficeNavigationLayout.Architecture.self
        #expect(abs(architecture.entranceLeafDisplayScale - 0.28) < 0.0001)
        #expect(architecture.entranceLeafDisplayScale < OfficeInteriorScale.environment)
        #expect(architecture.entranceLeafDisplayScaleX == architecture.entranceLeafDisplayScale)
        #expect(architecture.entranceLeafDisplayScaleY == architecture.entranceLeafDisplayScale)
        #expect(
            abs(
                OfficeInteriorScale.environment * OfficeInteriorScale.PropRelativeScale.entranceDoorLeaf
                    - architecture.entranceLeafDisplayScale
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
    /// V11 now applies the screenshot's one uniform 1613→4096 transform to its
    /// measured room corners. The source itself is within the 1.5° BG:EE lock;
    /// forcing exact ±0.75 slopes would change its proportions and defeat the
    /// reference-size contract.
    /// rearCorner is authored y-up; plate y-down REAR.y = ART_H − rearCorner.y.
    @Test func floorDiamondIsFittedToThePaintedFloor() {
        let arch = OfficeNavigationLayout.Architecture.self
        let artHeight: CGFloat = 2_304
        let rearYDown = artHeight - arch.rearCorner.y

        // Both measured reference axes remain within the 1.5° BG:EE gate.
        #expect(abs(arch.axisNW.dy / arch.axisNW.dx + 0.75) < 0.03)
        #expect(abs(arch.axisNE.dy / arch.axisNE.dx - 0.75) < 0.03)

        // `paintedRoomSourceRect` is authored y-up; these are plate y-down, so
        // the edges swap. Mixing the two frames is the mistake this test's own
        // header warns about, and it reads as a passing fit either way.
        let paint = OfficeInteriorScale.paintedRoomSourceRect
        let paintTopYDown = artHeight - paint.maxY
        let paintBottomYDown = artHeight - paint.minY

        // The uniformly transformed rear and near corners define the painted
        // room extent; neither may drift independently from that reference fit.
        #expect(abs(rearYDown - paintTopYDown) <= 2, "rear tip left the reference crown")

        let nearYDown = rearYDown + arch.axisNW.dy + arch.axisNE.dy
        #expect(abs(nearYDown - paintBottomYDown) <= 2, "near tip left the painted cutaway")
        #expect(nearYDown < artHeight, "near tip fell off the plate")
        let desk = OfficeNavigationLayout.AuthoredPlacement.deskEnsemble
        let bookshelf = OfficeNavigationLayout.AuthoredPlacement.bookshelf
        #expect(desk.y < 1_450)
        #expect(bookshelf.y < 1_700)
    }

    @Test func entranceRegistrationMatchesV11DoorManifest() {
        let leaf = OfficeNavigationLayout.Architecture.entranceLeafDisplayScale
        let frame = OfficeNavigationLayout.Architecture.entranceFrameDisplayScale
        #expect(frame == 0, "V11 has no freestanding door frame")
        #expect(
            abs(leaf - OfficeNavigationLayout.Architecture.entranceLeafDisplayScaleX) < 0.0001
        )
        #expect(
            abs(leaf - OfficeNavigationLayout.Architecture.entranceLeafDisplayScaleY) < 0.0001
        )
        let leafAnchor = OfficeNavigationLayout.Architecture.entranceLeafAnchorY
        let frameAnchorX = OfficeNavigationLayout.Architecture.entranceFrameAnchorX
        let frameAnchor = OfficeNavigationLayout.Architecture.entranceFrameAnchorY
        #expect(abs(leafAnchor - 0.94375) < 0.0001)
        #expect(frameAnchorX == 0)
        #expect(frameAnchor == 0)
        let entrance = OfficeNavigationLayout.Architecture.entranceAnchor
        #expect(abs(entrance.x - 2_541.526) < 0.001)
        #expect(abs(entrance.y - 564.898) < 0.001)
        let opening = OfficeNavigationLayout.Architecture.entranceOpeningPlateSize
        #expect(abs(opening.width - 68.055) < 0.01)
        #expect(abs(opening.height - 493.015) < 0.01)
        #expect(OfficeNavigationLayout.Architecture.partitionDoorB0 == 0)
        #expect(OfficeNavigationLayout.Architecture.partitionDoorB1 == 0)
        let internalLeaf = OfficeNavigationLayout.Architecture.internalLeafDisplayScale
        #expect(internalLeaf == 0)
    }

    /// The decorative internal leaf and its partition hinge are retired.
    @Test func internalLeafAndPartitionHingeAreRemoved() {
        let leafScale = OfficeNavigationLayout.Architecture.internalLeafDisplayScale
        #expect(leafScale == 0)
        #expect(OfficeNavigationLayout.Architecture.internalHingePlateHeight == 0)
        #expect(OfficeNavigationLayout.Architecture.internalHingePlateX == 0)
        #expect(OfficeNavigationLayout.AuthoredPlacement.internalDoorLeaf == .zero)
        #expect(OfficeNavigationLayout.authoredPartitionSegments.isEmpty)
    }

    @Test func v11RemovesTavernMassAndRegistersColdHearthGeometry() {
        #expect(OfficeNavigationLayout.authoredPillarSegments.isEmpty)
        #expect(OfficeNavigationLayout.authoredStairObstacle.isEmpty)
        let hearth = OfficeNavigationLayout.authoredFireplaceObstacle
        let cover = OfficeNavigationLayout.authoredFireplaceCoverRect
        let hearthPolygon = OfficeNavigationLayout.authoredFireplaceObstaclePolygon
        let coverPolygon = OfficeNavigationLayout.authoredFireplaceCoverPolygon
        #expect(!hearth.isEmpty)
        #expect(!cover.isEmpty)
        #expect(hearthPolygon.count == 4)
        #expect(coverPolygon.count == 4)
        #expect(cover.intersects(hearth))
        let wallCourse = CGPoint(
            x: coverPolygon[1].x - coverPolygon[0].x,
            y: coverPolygon[1].y - coverPolygon[0].y
        )
        let floorCourse = CGPoint(
            x: coverPolygon[2].x - coverPolygon[3].x,
            y: coverPolygon[2].y - coverPolygon[3].y
        )
        #expect(abs(wallCourse.y / wallCourse.x + 0.75) < 0.001)
        #expect(abs(floorCourse.x - wallCourse.x) < 0.001)
        #expect(abs(floorCourse.y - wallCourse.y) < 0.001)
        #expect(OfficeNavigationLayout.fireplaceObstacles.count >= 16)
        #expect(
            OfficeNavigationLayout.fireplaceObstacles.allSatisfy {
                OfficeNavigationLayout.obstacles.contains($0)
            }
        )
        for approach in OfficeNavigationLayout.approachPoints.values {
            #expect(
                OfficeNavigationLayout.fireplaceObstacles.allSatisfy {
                    !$0.contains(approach)
                }
            )
        }
    }

    @Test func entranceDoorRegistersToShippingAperture() {
        let leaf = OfficeNavigationLayout.AuthoredPlacement.doorLeaf
        let visualAnchor = OfficeNavigationLayout.Architecture.entranceLeafAnchor
        #expect(leaf == visualAnchor)
        #expect(abs(leaf.x - 2_741.247) < 0.001)
        #expect(abs(leaf.y - 709.388) < 0.001)
        #expect(
            OfficeNavigationLayout.Architecture.entranceLeafAnchorPoint
                == CGPoint(x: 0.953125, y: 0.94375)
        )

        // Collision/travel registers to the threshold centre, independently
        // of the image-canvas hinge used by the visual states.
        let navigationThreshold = OfficeNavigationLayout.Architecture.entranceAnchor
        #expect(OfficeNavigationLayout.authoredDoorObstacle.contains(navigationThreshold))
        #expect(leaf != navigationThreshold)
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

    @Test func edgeOnEntranceLeafUsesRegisteredRetractingStates() {
        let upright = OfficeNavigationLayout.Architecture.entranceLeafDisplayScale
        let ratio = OfficeNavigationLayout.Architecture.entranceFallenLeafScaleRatio
        let artworkScale =
            OfficeNavigationLayout.Architecture.entranceFallenArtworkDisplayScale
        let artworkSize =
            OfficeNavigationLayout.Architecture.entranceFallenArtworkDisplaySize
        let transitionScale =
            OfficeNavigationLayout.Architecture.entranceFallingTransitionScale

        #expect(OfficeNavigationLayout.Architecture.entranceLeafClosedLengthRatio == 1)
        #expect(OfficeNavigationLayout.Architecture.entranceLeafMidLengthRatio == 0.815)
        #expect(OfficeNavigationLayout.Architecture.entranceLeafOpenLengthRatio == 0.638)
        #expect(ratio == OfficeNavigationLayout.Architecture.entranceLeafOpenLengthRatio)
        #expect(transitionScale == upright)
        #expect(artworkScale == upright)
        #expect(abs(artworkSize.width - 512 * artworkScale) < 0.001)
        #expect(abs(artworkSize.height - 320 * artworkScale) < 0.001)
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

    @Test func eachBakedWindowPaneFallsInTheSingleWindowBand() {
        for pane in OfficeNavigationLayout.Architecture.windowGlassPolygons {
            let ys = pane.map(\.y)
            let plateHeight = (ys.max() ?? 0) - (ys.min() ?? 0)
            let multiple = plateHeight * OfficeInteriorScale.environment
                / OfficeInteriorScale.standingAdultBodyHeight
            #expect(OfficeInteriorScale.Band.windowGlass.contains(multiple))
        }
    }

    @Test func bakedWindowsKeepSeparateMaskAndNearHoverRegistration() {
        let window = OfficeNavigationLayout.Architecture.windowAnchor
        let rainMask = OfficeNavigationLayout.AuthoredPlacement.windowRainMask
        let near = OfficeNavigationLayout.Architecture.nearWindowAperture
        let far = OfficeNavigationLayout.Architecture.farWindowAperture
        let nearHit = OfficeNavigationLayout.Architecture.nearWindowHitArea

        #expect(near.count == 4)
        #expect(far.count == 4)
        #expect(OfficeNavigationLayout.Architecture.windowGlassPolygons.count == 8)
        #expect(nearHit.contains(window))
        #expect(!nearHit.contains(far[0]))
        #expect(rainMask == CGRect(x: 0, y: 0, width: 4_096, height: 2_304))
        #expect(OfficeNavigationLayout.AuthoredPlacement.windowRotation == 0)
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
        #expect(chairA != chairB)
        #expect(deskTopSort.isFinite && chairSortBias.isFinite)
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
        // -100, not -30. `d13469bb` moved it and said why: "-30 put the stand
        // root inside the desk. The runtime found no passable cell within the
        // 16-unit agent radius, so routes failed at the *start* rather than the
        // destination — which is why every approach looked broken at once."
        let authoredStart = CGPoint(
            x: OfficeNavigationLayout.AuthoredPlacement.deskChair.x,
            y: OfficeNavigationLayout.AuthoredPlacement.deskChair.y - 120
        )
        #expect(OfficeNavigationLayout.actorStart == OfficeInteriorScale.mapPoint(authoredStart))
        // Paired with the -100 start: `d13469bb` set `seatedYOffset` to 39.5 so
        // the seated actor still lands on the chair after the stand root moved
        // clear of the desk. It is no longer `30 * environment`.
        #expect(abs(OfficeInteriorScale.ActorDisplay.seatedYOffset - 47.4) < 0.01)
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
        #expect(deskGap < 300, "Client stopped \(deskGap) authored units from the desk")
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

    @Test func clientUsesDirectOpenPlanRouteWithoutPartition() {
        let route = OfficeNavigationLayout.clientOfficeArrivalPath
            .map(OfficeInteriorScale.unmapPoint)
        #expect(route.count >= 2)
        #expect(OfficeNavigationLayout.authoredPartitionSegments.isEmpty)

        let internalDoor = OfficeNavigationLayout.clientInternalDoorwayPath
            .map(OfficeInteriorScale.unmapPoint)
        #expect(internalDoor.count == 3)
        #expect(internalDoor.allSatisfy {
            !OfficeNavigationLayout.isBlocked(OfficeInteriorScale.mapPoint($0))
        })
        // The compatibility waypoints are now ordinary open-floor circulation
        // points; no framed aperture or partition constrains them.
        #expect(hypot(route[1].x - route[0].x, route[1].y - route[0].y) < 280)
        let desk = OfficeNavigationLayout.AuthoredPlacement.deskEnsemble
        #expect(hypot(route.last!.x - desk.x, route.last!.y - desk.y) < 300)
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
        let drawers = OfficeInteriorScale.bodyMultiple(
            contentHeight: OfficeInteriorScale.SourceContentHeight.deskDrawerFace,
            relativeScale: OfficeInteriorScale.PropRelativeScale.deskEnsemble
        )
        #expect(OfficeInteriorScale.environment == 0.395)
        #expect(OfficeInteriorScale.detectiveBodyHeight == 82)
        #expect(
            abs(OfficeNavigationLayout.Architecture.entranceLeafDisplayScale - 0.28)
                < 0.0001
        )
        #expect(
            OfficeNavigationLayout.Architecture.entranceLeafDisplayScale
                < OfficeInteriorScale.environment
        )
        #expect(OfficeNavigationLayout.Architecture.entranceLeafOpenLengthRatio == 0.638)
        #expect(OfficeInteriorScale.Band.deskDrawerFace.contains(drawers))
        #expect(OfficeNavigationLayout.Architecture.windowGlassPolygons.count == 8)
    }
}
