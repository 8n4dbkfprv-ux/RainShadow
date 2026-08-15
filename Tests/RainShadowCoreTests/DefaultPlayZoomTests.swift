import CoreGraphics
import Testing
@testable import RainShadowCore

struct DefaultPlayZoomTests {
    /// BG:EE area-view density: a standing adult is ~9% of the visible height.
    @Test func bandMatchesBGEEAreaDensity() {
        #expect(DefaultPlayZoom.bodyToVisibleHeightBand == 0.080...0.100)
        #expect(DefaultPlayZoom.targetBodyToVisibleHeight == 0.09)
        #expect(DefaultPlayZoom.bodyToVisibleHeightBand.contains(DefaultPlayZoom.targetBodyToVisibleHeight))
    }

    /// The BG1 figure is measurable — a ~50 px adult on a 512×384 playfield —
    /// where BG:EE's 9% is a documented reading of a zoomable view. So assert
    /// the thing that can be checked: BG1's density is still *reachable*, one
    /// zoom step short of a third of the way down the band, which is what makes
    /// this a change of default rather than of range.
    @Test func originalBG1DensityRemainsReachableAsAZoomStep() {
        let body = OfficeInteriorScale.renderedStandingDetectiveBodyHeight
        let base = OfficeInteriorScale.cameraVisibleHeight
        let bg1 = 50.0 / 384.0
        let atStep10 = body / CameraZoom.visibleHeight(base: base, step: 10)
        #expect(abs(atStep10 - bg1) < 0.005)
        #expect(CameraZoom.engineStepRange.contains(10))
        // And the default really is wider than BG1 was.
        #expect(DefaultPlayZoom.targetBodyToVisibleHeight < bg1)
    }

    @Test func cityStandingBodyFallsInBGBand() {
        let bodyHeight = OfficeInteriorScale.renderedStandingDetectiveBodyHeight
        let fraction = DefaultPlayZoom.standingBodyFraction(
            bodyHeight: bodyHeight,
            visibleWorldHeight: CityDistrictLayout.cameraVisibleHeight
        )
        #expect(DefaultPlayZoom.isInBand(
            bodyHeight: bodyHeight,
            visibleWorldHeight: CityDistrictLayout.cameraVisibleHeight
        ))
        #expect(DefaultPlayZoom.bodyToVisibleHeightBand.contains(fraction))
        #expect(abs(fraction - DefaultPlayZoom.targetBodyToVisibleHeight) < 0.0001)
    }

    @Test func cityUsesDefaultPlayZoomVisibleHeight() {
        #expect(
            abs(
                CityDistrictLayout.cameraVisibleHeight
                    - DefaultPlayZoom.cameraVisibleHeight(
                        standingBodyHeight: OfficeInteriorScale.renderedStandingDetectiveBodyHeight
                    )
            ) < 0.0001
        )
    }

    @Test func officeMatchesSharedBGEEMidBandDensity() {
        let officeFraction = OfficeInteriorScale.renderedStandingDetectiveBodyHeight
            / OfficeInteriorScale.cameraVisibleHeight
        #expect(DefaultPlayZoom.bodyToVisibleHeightBand.contains(officeFraction))
        #expect(abs(officeFraction - OfficeInteriorScale.playBodyToVisibleHeight) < 0.0001)
        #expect(abs(officeFraction - DefaultPlayZoom.targetBodyToVisibleHeight) < 0.0001)
        #expect(
            abs(
                OfficeInteriorScale.cameraVisibleHeight
                    - CityDistrictLayout.cameraVisibleHeight
            ) < 0.0001
        )
    }

    @Test func cameraScaleIsUniformVisibleHeightOverSceneHeight() {
        let visible: CGFloat = OfficeInteriorScale.cameraVisibleHeight
        let sceneHeights: [CGFloat] = [768, 1_152, 1_440, 2_160]
        for sceneHeight in sceneHeights {
            let scale = DefaultPlayZoom.cameraScale(
                visibleWorldHeight: visible,
                sceneHeight: sceneHeight
            )
            #expect(abs(scale - visible / sceneHeight) < 0.000_000_1)
            #expect(scale > 0)
        }
        #expect(DefaultPlayZoom.cameraScale(visibleWorldHeight: visible, sceneHeight: 0) == 1)
    }

    @Test func officePlateFullyCoversTheViewportAtPlayDensity() {
        // At the BG1 density the plate is larger than the viewport in both axes,
        // so the room pans like a BG area and no black void shows past its edge.
        // The old 9% framing was wider than the plate and accepted that void.
        let visibleHeight = OfficeInteriorScale.cameraVisibleHeight
        let visibleWidth = visibleHeight * 16 / 9
        let heightCoverage = OfficeInteriorScale.scaledArtSize.height / visibleHeight
        let widthCoverage = OfficeInteriorScale.scaledArtSize.width / visibleWidth
        #expect(heightCoverage >= 1)
        #expect(widthCoverage >= 1)
        // Not so tight that the room becomes a keyhole.
        #expect(heightCoverage < 2.5)
    }

    @Test func furnitureBodyMultiplesStillHoldWithSharedCameraDensity() {
        // Camera framing must not require changing furniture vs body.
        let door = OfficeInteriorScale.bodyMultiple(
            contentHeight: OfficeInteriorScale.SourceContentHeight.doorLeaf,
            relativeScale: OfficeInteriorScale.PropRelativeScale.entranceDoorLeaf
        )
        let window = OfficeInteriorScale.bodyMultiple(
            contentHeight: OfficeInteriorScale.SourceContentHeight.windowGlassOpening
        )
        let drawers = OfficeInteriorScale.bodyMultiple(
            contentHeight: OfficeInteriorScale.SourceContentHeight.deskDrawerFace,
            relativeScale: OfficeInteriorScale.PropRelativeScale.deskEnsemble
        )
        #expect(OfficeInteriorScale.Band.door.contains(door))
        #expect(OfficeInteriorScale.Band.windowGlass.contains(window))
        #expect(OfficeInteriorScale.Band.deskDrawerFace.contains(drawers))
        #expect(OfficeInteriorScale.environment == 0.395)
        #expect(OfficeInteriorScale.detectiveBodyHeight == 82)
    }
}
