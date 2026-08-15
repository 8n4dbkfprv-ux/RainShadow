import CoreGraphics
import Testing
@testable import RainShadowCore

struct CameraZoomTests {
    /// The two plate rects, recomputed here from the authored source rather than
    /// read off `OfficeInteriorScale`, so a scale change has to be acknowledged
    /// in both places.
    private static let officePlate = OfficeInteriorScale.worldBounds
    private static let officeRoom = OfficeInteriorScale.paintedRoomBounds
    private static let officeAnchor = CGPoint(x: officeRoom.midX, y: officeRoom.midY)
    private static let cityPlate = CityDistrictDefinition.worldBounds
    private static let cityAnchor = CGPoint(x: cityPlate.midX, y: cityPlate.midY)
    private static let base = OfficeInteriorScale.cameraVisibleHeight

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

    @Test func defaultStepIsANoOpAgainstTheShippedPlayDensity() {
        // Zoom must not move the camera the game already ships with: step 16 has
        // to reproduce `DefaultPlayZoom.cameraVisibleHeight` exactly.
        let visible = CameraZoom.visibleHeight(base: Self.base, step: CameraZoom.defaultStep)
        #expect(abs(visible - Self.base) < 0.000_1)
        #expect(
            abs(visible - DefaultPlayZoom.cameraVisibleHeight(
                standingBodyHeight: OfficeInteriorScale.renderedStandingDetectiveBodyHeight
            )) < 0.000_1
        )
        // And the body still reads at the BG1 density there.
        #expect(DefaultPlayZoom.isInBand(
            bodyHeight: OfficeInteriorScale.renderedStandingDetectiveBodyHeight,
            visibleWorldHeight: visible
        ))
    }

    @Test func zoomBandSpansAPortraitShotToRoughlyBGEEsOwnDensity() {
        let body = OfficeInteriorScale.renderedStandingDetectiveBodyHeight
        let tightest = CameraZoom.visibleHeight(base: Self.base, step: 1)
        let widest = CameraZoom.visibleHeight(base: Self.base, step: 27)
        // 25% is a 4x magnification: the adult fills over half the view height.
        #expect(abs(body / tightest - 0.52) < 0.01)
        // 155% lands near the ~9% density BG:EE's widescreen view shows, which
        // `DefaultPlayZoom` documents and deliberately does not use as default.
        #expect(abs(body / widest - 0.084) < 0.005)
    }

    @Test func officeCeilingIsBoundVerticallyAtSixteenNine() {
        // Painted room centre y 1220.14 vs plate centre 1152, so the headroom is
        // asymmetric: 386.90 up against 523.18 down. 2 x 386.90 = 773.81 world
        // units of viewport, which is 143.07% — floor to a 5-point step: 140%.
        let step = CameraZoom.fitStep(
            base: Self.base,
            viewportAspect: 16.0 / 9.0,
            anchor: Self.officeAnchor,
            plate: Self.officePlate
        )
        #expect(step == 24)
        #expect(CameraZoom.percent(forStep: step) == 140)
    }

    @Test func officeCeilingTightensOnAWiderWindow() {
        // At 21:9 the plate's 1617.92 width binds before its height does, so the
        // ceiling has to be resolved against the live view, not baked.
        let step = CameraZoom.fitStep(
            base: Self.base,
            viewportAspect: 21.0 / 9.0,
            anchor: Self.officeAnchor,
            plate: Self.officePlate
        )
        #expect(step == 21)
        #expect(step < CameraZoom.fitStep(
            base: Self.base,
            viewportAspect: 16.0 / 9.0,
            anchor: Self.officeAnchor,
            plate: Self.officePlate
        ))
    }

    @Test func cityCeilingIsTheEngineCapNotThePlate() {
        // The district plate could carry 213%; BG:EE's own 155% binds first.
        let step = CameraZoom.fitStep(
            base: Self.base,
            viewportAspect: 16.0 / 9.0,
            anchor: Self.cityAnchor,
            plate: Self.cityPlate
        )
        #expect(step == CameraZoom.engineStepRange.upperBound)
        let widest = CameraZoom.visibleHeight(base: Self.base, step: step)
        #expect(widest * 16 / 9 <= Self.cityPlate.width)
        #expect(widest <= Self.cityPlate.height)
    }

    @Test func everyReachableStepKeepsTheViewportInsideThePlate() {
        // The property, not just the endpoint: no step the player can reach may
        // show void past the painted edge. This is the rule the Infinity Engine
        // does *not* keep — MoveViewportTo centres the map and lets black show.
        for (anchor, plate, aspect) in [
            (Self.officeAnchor, Self.officePlate, 16.0 / 9.0),
            (Self.officeAnchor, Self.officePlate, 21.0 / 9.0),
            (Self.officeAnchor, Self.officePlate, 4.0 / 3.0),
            (Self.cityAnchor, Self.cityPlate, 16.0 / 9.0),
            (Self.cityAnchor, Self.cityPlate, 21.0 / 9.0)
        ] {
            let ceiling = CameraZoom.fitStep(
                base: Self.base,
                viewportAspect: CGFloat(aspect),
                anchor: anchor,
                plate: plate
            )
            for step in CameraZoom.engineStepRange.lowerBound...ceiling {
                let height = CameraZoom.visibleHeight(base: Self.base, step: step)
                let width = height * CGFloat(aspect)
                let viewport = CGRect(
                    x: anchor.x - width / 2,
                    y: anchor.y - height / 2,
                    width: width,
                    height: height
                )
                #expect(plate.insetBy(dx: -0.001, dy: -0.001).contains(viewport))
            }
        }
    }

    @Test func fitStepDegradesToTheFloorRatherThanCrashingOnAnEmptyPlate() {
        #expect(CameraZoom.fitStep(
            base: 0,
            viewportAspect: 16.0 / 9.0,
            anchor: .zero,
            plate: Self.cityPlate
        ) == 1)
        #expect(CameraZoom.fitStep(
            base: Self.base,
            viewportAspect: 16.0 / 9.0,
            anchor: .zero,
            plate: .zero
        ) == 1)
    }
}
