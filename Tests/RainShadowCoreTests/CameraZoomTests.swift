import CoreGraphics
import Testing
@testable import RainShadowCore

struct CameraZoomTests {
    /// The two area rects each scene hands the viewport clamp — the office's
    /// painted room and a ward's plate.
    private static let officeRoom = OfficeInteriorScale.paintedRoomBounds
    private static let cityPlate = CityDistrictDefinition.worldBounds
    private static let viewHeight: CGFloat = 1_152
    private static let base = OfficeInteriorScale.cameraVisibleHeight(forSceneHeight: viewHeight)

    @Test func stepModelMatchesTheEnhancedEditionEngine() {
        // GemRB GameControl: `zoomLevel = 16; // 100%`, `20 + zoomLevel * 5`.
        #expect(CameraZoom.defaultStep == 16)
        #expect(CameraZoom.percent(forStep: CameraZoom.defaultStep) == 100)
        #expect(CameraZoom.engineStepRange == 1...27)
        // "EEs have 27 zoom steps", clamped 1…27 by OnMouseWheelScroll.
        #expect(CameraZoom.percent(forStep: 1) == 25)
        #expect(CameraZoom.percent(forStep: 27) == 155)
    }

    @Test func stridesFivePercentagePointsLinearlyNotMultiplicatively() {
        // The engine adds a fixed 5 points per notch. One notch near the default
        // is a 5% change; one notch near the floor is 20%. That asymmetry is the
        // property under test — a ratio-based zoom would not have it.
        for step in 1..<27 {
            #expect(CameraZoom.percent(forStep: step + 1) - CameraZoom.percent(forStep: step) == 5)
        }
        let nearDefault = CameraZoom.percent(forStep: 17) / CameraZoom.percent(forStep: 16)
        let nearFloor = CameraZoom.percent(forStep: 2) / CameraZoom.percent(forStep: 1)
        #expect(nearFloor > nearDefault)
    }

    @Test func percentRoundTripsThroughStep() {
        for step in CameraZoom.engineStepRange {
            #expect(CameraZoom.step(forPercent: CameraZoom.percent(forStep: step)) == step)
        }
    }

    @Test func settablePercentClampsExactlyWhereSetScalePercentDoes() {
        // `Clamp(level, 25u, 160u); zoomLevel = (value - 20) / 5;` — 160 lands on
        // step 28, one past the wheel's ceiling. Reproduced, not tidied.
        #expect(CameraZoom.step(forPercent: 0) == 1)
        #expect(CameraZoom.step(forPercent: 25) == 1)
        #expect(CameraZoom.step(forPercent: 160) == 28)
        #expect(CameraZoom.step(forPercent: 9_999) == 28)
        #expect(CameraZoom.clamped(step: 28, to: CameraZoom.engineStepRange) == 27)
        #expect(CameraZoom.clamped(step: 0, to: CameraZoom.engineStepRange) == 1)
    }

    @Test func defaultStepIsANoOpAgainstTheNativeCalibration() {
        // GemRB returns before Region::Scale at 100%.
        let visible = CameraZoom.visibleHeight(base: Self.base, step: CameraZoom.defaultStep)
        #expect(abs(visible - Self.base) < 0.000_1)
        #expect(OfficeInteriorScale.renderedStandingDetectiveBodyHeight / visible * Self.viewHeight == 64)
    }

    @Test func zoomBandRetainsItsFourTimesMagnificationAtTheNearEnd() {
        let body = OfficeInteriorScale.renderedStandingDetectiveBodyHeight
        let tightest = CameraZoom.visibleHeight(base: Self.base, step: 1)
        let widest = CameraZoom.visibleHeight(base: Self.base, step: 27)
        #expect(body / tightest * Self.viewHeight == 256)
        #expect(abs(body / widest * Self.viewHeight - 64 / 1.55) < 1e-10)
    }

    @Test func everyAreaReachesTheSameBandIndoorsAndOut() {
        // The point of the port. The band no longer depends on plate size or on
        // the window's aspect: `MoveViewportTo` allows 1…27 everywhere and
        // clamps the viewport instead. Before this, the office ceiling was step
        // 16 at 16:9 — no zoom-out at all — and step 13 at 21:9, below the
        // default the whole game is framed against.
        #expect(CameraZoom.engineStepRange == 1...27)
        for base in [Self.base, CityDistrictLayout.cameraVisibleHeight(forSceneHeight: Self.viewHeight)] {
            for step in CameraZoom.engineStepRange {
                #expect(CameraZoom.clamped(step: step, to: CameraZoom.engineStepRange) == step)
                #expect(CameraZoom.visibleHeight(base: base, step: step) > 0)
            }
        }
    }

    @Test func theWidestStepOutgrowsTheOfficeAndNotTheWard() {
        // The two ends of the accepted trade, stated as numbers. Indoors the
        // 155% viewport is larger than the area in both axes, so `AreaViewport`
        // centres it and black shows; a ward is still larger than the viewport,
        // so nothing about the outdoor framing moves.
        let widest = CameraZoom.visibleHeight(base: Self.base, step: 27)
        let width = widest * 16 / 9
        #expect(width > Self.officeRoom.width)
        #expect(widest > Self.officeRoom.height)
        #expect(width < Self.cityPlate.width)
        #expect(widest < Self.cityPlate.height)
    }
}
