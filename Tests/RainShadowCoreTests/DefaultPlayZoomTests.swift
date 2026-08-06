import CoreGraphics
import Testing
@testable import RainShadowCore

struct DefaultPlayZoomTests {
    @Test func bandIsEightToElevenPercent() {
        #expect(DefaultPlayZoom.bodyToVisibleHeightBand == 0.08...0.11)
        #expect(DefaultPlayZoom.targetBodyToVisibleHeight == 0.09)
        #expect(DefaultPlayZoom.bodyToVisibleHeightBand.contains(DefaultPlayZoom.targetBodyToVisibleHeight))
    }

    @Test func cityStandingBodyFallsInBGEEBand() {
        let bodyHeight = OfficeInteriorScale.renderedStandingDetectiveBodyHeight
        let fraction = DefaultPlayZoom.standingBodyFraction(
            bodyHeight: bodyHeight,
            visibleWorldHeight: CityDistrictLayout.cameraVisibleHeight
        )
        #expect(DefaultPlayZoom.isInBand(
            bodyHeight: bodyHeight,
            visibleWorldHeight: CityDistrictLayout.cameraVisibleHeight
        ))
        #expect(fraction >= 0.08 && fraction <= 0.11)
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

    @Test func correctlyAuthoredOfficeFillsThePlayableHeight() {
        let shellFill = OfficeInteriorScale.scaledArtSize.height
            / OfficeInteriorScale.cameraVisibleHeight
        // Mid-band (rendered 9%) is slightly taller than the 0.395-mapped plate;
        // a thin IE-style black void past the plate edge is acceptable.
        #expect(shellFill > 0.85 && shellFill < 1.25)
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
