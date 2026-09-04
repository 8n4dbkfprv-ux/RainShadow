import CoreGraphics
import Testing
@testable import RainShadowCore

struct DefaultPlayZoomTests {
    @Test func hundredPercentShowsThe64RowBodyAt64LogicalPoints() {
        let body = OfficeInteriorScale.renderedStandingDetectiveBodyHeight
        let native = OfficeInteriorScale.ActorDisplay.nativeStandingBodyPixelHeight
        #expect(native == 64)
        #expect(body == 70.3125) // World geometry is deliberately unchanged.
        #expect(OfficeInteriorScale.cameraScaleAt100Percent == 1.0986328125)
        #expect(DefaultPlayZoom.displayedBodyHeight(
            bodyHeight: body,
            cameraScale: OfficeInteriorScale.cameraScaleAt100Percent
        ) == native)
    }

    @Test func resizingRevealsMoreWorldWithoutMagnifyingTheActor() {
        let scale = OfficeInteriorScale.cameraScaleAt100Percent
        for height: CGFloat in [390, 720, 911, 1_152, 1_440, 2_160] {
            let visible = OfficeInteriorScale.cameraVisibleHeight(forSceneHeight: height)
            #expect(visible == height * scale)
            #expect(DefaultPlayZoom.cameraScale(
                visibleWorldHeight: visible, sceneHeight: height
            ) == scale)
            #expect(OfficeInteriorScale.renderedStandingDetectiveBodyHeight / visible * height == 64)
        }
        #expect(OfficeInteriorScale.cameraVisibleHeight(forSceneHeight: 1_440)
            == 2 * OfficeInteriorScale.cameraVisibleHeight(forSceneHeight: 720))
    }

    @Test func nativeCalibrationIsBoundToTheInstalledIndexedBody() throws {
        let sprite = try IEIndexedSprite.load(character: "Voss")
        let frame = try #require(sprite.frame(atlas: "VossIdle.atlas", name: "voss_standing_idle_sw_00.png"))
        #expect(sprite.textureFilter == .linear)
        #expect(frame.nativeSize == .init(width: 26, height: 64))
        let scale = Double(OfficeInteriorScale.cameraScaleAt100Percent)
        #expect(Double(frame.size.height) * sprite.displayUnitsPerSourcePixel.y / scale == 64)
        // 81 registered columns / 3.125 = 25.92 points. Keep the accepted
        // canvas/pivot registration instead of quietly rescaling every crop.
        #expect(abs(Double(frame.size.width) * sprite.displayUnitsPerSourcePixel.x / scale - 25.92) < 1e-10)
        // Nearest-integer registered dimensions can differ from native width
        // or height by at most half a source pixel: 0.5 / 3.125 = 0.16 points.
        for crop in sprite.frames where !crop.isEmpty {
            #expect(abs(Double(crop.size.width) * sprite.displayUnitsPerSourcePixel.x / scale
                - Double(crop.nativeSize.width)) <= 0.160_000_1)
            #expect(abs(Double(crop.size.height) * sprite.displayUnitsPerSourcePixel.y / scale
                - Double(crop.nativeSize.height)) <= 0.160_000_1)
        }
    }

    @Test func officeAndCityShareOneNativePixelScale() {
        #expect(CityDistrictLayout.cameraScaleAt100Percent == OfficeInteriorScale.cameraScaleAt100Percent)
        for height: CGFloat in [390, 720, 1_152] {
            #expect(CityDistrictLayout.cameraVisibleHeight(forSceneHeight: height)
                == OfficeInteriorScale.cameraVisibleHeight(forSceneHeight: height))
        }
    }

    @Test func zoomMagnifiesTheEntireViewByTheEnginePercent() {
        let body = OfficeInteriorScale.renderedStandingDetectiveBodyHeight
        for height: CGFloat in [720, 1_152] {
            let base = OfficeInteriorScale.cameraVisibleHeight(forSceneHeight: height)
            for step in CameraZoom.engineStepRange {
                let visible = CameraZoom.visibleHeight(base: base, step: step)
                let points = body / visible * height
                #expect(abs(points - 64 * 100 / CameraZoom.percent(forStep: step)) < 1e-10)
            }
        }
    }

    @Test func cinematicFixedHeightConversionRemainsAvailable() {
        #expect(DefaultPlayZoom.cameraScale(visibleWorldHeight: 1_152, sceneHeight: 720) == 1.6)
        #expect(DefaultPlayZoom.cameraScale(visibleWorldHeight: 1_152, sceneHeight: 0) == 1)
        #expect(DefaultPlayZoom.nativeSpriteCameraScale(standingBodyHeight: 70, nativeBodyPixelHeight: 0) == 1)
        #expect(DefaultPlayZoom.cameraVisibleHeight(sceneHeight: 0, cameraScale: 1) == 0)
    }

    @Test func furnitureBodyMultiplesStillHoldWithSharedCameraDensity() {
        // Camera framing must not change furniture vs body. The separate V12
        // door edge intentionally uses its own smaller reference-matched scale.
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
