import CoreGraphics
import Testing
@testable import RainShadowCore

struct OfficeInteriorScaleTests {
    @Test func actorFramesUseTheSameNativeRoomScale() {
        #expect(OfficeInteriorScale.Band.standingBody.contains(OfficeInteriorScale.detectiveBodyHeight))
        #expect(OfficeInteriorScale.ActorDisplay.standingScale == 1)
        #expect(OfficeInteriorScale.ActorDisplay.standingScale == OfficeInteriorScale.ActorDisplay.seatedScale)
    }

    @Test func chairMatchesTheSeatedVisualBaseline() {
        let chair = OfficeInteriorScale.mapPoint(OfficeNavigationLayout.AuthoredPlacement.deskChair)
        let seatedBaseline = OfficeNavigationLayout.actorStart.y
            + OfficeInteriorScale.ActorDisplay.seatedYOffset
        #expect(abs(chair.x - OfficeNavigationLayout.actorStart.x) < 0.5)
        #expect(abs(chair.y - seatedBaseline) < 0.5)
    }

    @Test func doorMultipleFallsInBGBand() {
        let multiple = OfficeInteriorScale.bodyMultiple(
            contentHeight: OfficeInteriorScale.SourceContentHeight.doorLeaf
        )
        #expect(OfficeInteriorScale.Band.door.contains(multiple))
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

    @Test func chairMultipleFallsInBGBand() {
        let multiple = OfficeInteriorScale.bodyMultiple(
            contentHeight: OfficeInteriorScale.SourceContentHeight.deskChair,
            relativeScale: OfficeInteriorScale.PropRelativeScale.deskChair
        )
        #expect(OfficeInteriorScale.Band.chair.contains(multiple))
    }

    @Test func cabinetMultipleFallsInBGBand() {
        let multiple = OfficeInteriorScale.bodyMultiple(
            contentHeight: OfficeInteriorScale.SourceContentHeight.filingCabinet
        )
        #expect(OfficeInteriorScale.Band.cabinet.contains(multiple))
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

    @Test func environmentIsUniformForShellAndProps() {
        #expect(OfficeInteriorScale.environment > 0)
        #expect(OfficeInteriorScale.environment < 1)
        let shell = OfficeInteriorScale.scaledArtSize
        #expect(shell.width == OfficeInteriorScale.sourceArtSize.width * OfficeInteriorScale.environment)
        #expect(shell.height == OfficeInteriorScale.sourceArtSize.height * OfficeInteriorScale.environment)
    }

    @Test func everyOfficeHotspotApproachIsReachableAfterScale() {
        let grid = OfficeNavigationLayout.makeGrid()
        for (hotspotID, destination) in OfficeNavigationLayout.approachPoints {
            let path = grid.path(from: OfficeNavigationLayout.actorStart, to: destination)
            #expect(path?.isEmpty == false, "Expected a route to \(hotspotID) after interior scale")
        }
    }

    @Test func actorStartAndApproachesUseMappedCoordinates() {
        let authoredStart = CGPoint(x: 1_430, y: 1_080)
        #expect(OfficeNavigationLayout.actorStart == OfficeInteriorScale.mapPoint(authoredStart))
        #expect(OfficeNavigationLayout.approachPoints["office.desk"] == OfficeInteriorScale.mapPoint(CGPoint(x: 1_235, y: 1_085)))
    }

    @Test func clientArrivalMovesSouthWestAlongClearFloor() {
        let path = OfficeNavigationLayout.clientArrivalPath
        #expect(path.count == 3)
        #expect(path.allSatisfy { !OfficeNavigationLayout.isBlocked($0) })
        guard let first = path.first, let last = path.last else { return }
        #expect(last.x < first.x)
        #expect(last.y < first.y)
    }

    @Test func clientDepartureRetracesClearFloorToTheDoor() {
        let departure = OfficeNavigationLayout.clientDeparturePath
        #expect(departure == Array(OfficeNavigationLayout.clientArrivalPath.reversed()))
        #expect(departure.allSatisfy { !OfficeNavigationLayout.isBlocked($0) })
        guard let first = departure.first, let last = departure.last else { return }
        #expect(last.x > first.x)
        #expect(last.y > first.y)
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
        let grid = OfficeNavigationLayout.makeGrid()
        let destination = OfficeNavigationLayout.approachPoints["office.door"]!
        let path = grid.path(from: OfficeNavigationLayout.actorStart, to: destination)
        #expect(path?.isEmpty == false)
        #expect(!OfficeNavigationLayout.doorObstacle.contains(destination))
        #expect(path?.allSatisfy { !OfficeNavigationLayout.doorObstacle.contains($0) } == true)
    }

    @Test func pathAcrossDoorwayIsBlockedOrRoutedAround() {
        let grid = OfficeNavigationLayout.makeGrid()
        // A point deep on the door leaf should not be a path endpoint.
        let onDoor = OfficeNavigationLayout.doorLeafSamplePoints[0]
        let pathOntoDoor = grid.path(from: OfficeNavigationLayout.actorStart, to: onDoor)
        #expect(pathOntoDoor == nil, "Must not pathfind onto the door leaf")
    }

    @Test func officeCameraFramesTheScaledRoom() {
        let visibleFraction = OfficeInteriorScale.scaledArtSize.height
            / OfficeInteriorScale.cameraVisibleHeight
        #expect(abs(visibleFraction - 0.86) < 0.001)
        #expect(OfficeInteriorScale.cameraVisibleHeight < 700)
    }

    @Test func scaleReportMatchesShippedContract() {
        let door = OfficeInteriorScale.bodyMultiple(
            contentHeight: OfficeInteriorScale.SourceContentHeight.doorLeaf
        )
        let drawers = OfficeInteriorScale.bodyMultiple(
            contentHeight: OfficeInteriorScale.SourceContentHeight.deskDrawerFace,
            relativeScale: OfficeInteriorScale.PropRelativeScale.deskEnsemble
        )
        let window = OfficeInteriorScale.bodyMultiple(
            contentHeight: OfficeInteriorScale.SourceContentHeight.windowGlassOpening
        )
        #expect(OfficeInteriorScale.environment == 0.28)
        #expect(OfficeInteriorScale.detectiveBodyHeight == 100)
        #expect(OfficeInteriorScale.Band.door.contains(door))
        #expect(OfficeInteriorScale.Band.deskDrawerFace.contains(drawers))
        #expect(OfficeInteriorScale.Band.windowGlass.contains(window))
    }
}
