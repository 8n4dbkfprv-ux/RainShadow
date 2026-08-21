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
        // 25% is a 4x magnification: the adult fills over a third of the height.
        #expect(abs(body / tightest - 0.36) < 0.01)
        // 155% is a genuine wide shot, well past any Infinity Engine framing.
        #expect(abs(body / widest - 0.058) < 0.005)
        // The default sits at BG:EE density, so both ends are real headroom.
        #expect(body / tightest > DefaultPlayZoom.targetBodyToVisibleHeight)
        #expect(body / widest < DefaultPlayZoom.targetBodyToVisibleHeight)
    }

    @Test func officeHasBarelyAnyHeadroomAtBGEEDensity() {
        // At BG:EE density the default viewport is already 86% of the plate in
        // both axes (coverage 1.165x), so the office can give back exactly one
        // zoom step before the painting runs out. That is the cost of the wider
        // default. V11's uniformly cropped compact room retains two steps; it
        // is worth failing loudly if the registered painted bounds drift.
        let step = CameraZoom.fitStep(
            base: Self.base,
            viewportAspect: 16.0 / 9.0,
            anchor: Self.officeAnchor,
            plate: Self.officePlate
        )
        #expect(step == 18)
        #expect(step > CameraZoom.defaultStep)
        // Still genuinely covered — the fit limit is not being skipped.
        let height = CameraZoom.visibleHeight(base: Self.base, step: step)
        #expect(height * 16 / 9 <= Self.officePlate.width)
        #expect(height <= Self.officePlate.height)
    }

    @Test func officeCeilingTightensOnAWiderWindow() {
        // At 21:9 the plate's 1617.92 width binds before its height does, so the
        // ceiling has to be resolved against the live view, not baked. This is
        // the case that keeps the fit limit honest now that 16:9 clears it.
        let step = CameraZoom.fitStep(
            base: Self.base,
            viewportAspect: 21.0 / 9.0,
            anchor: Self.officeAnchor,
            plate: Self.officePlate
        )
        #expect(step == 13)
        #expect(step < CameraZoom.fitStep(
            base: Self.base,
            viewportAspect: 16.0 / 9.0,
            anchor: Self.officeAnchor,
            plate: Self.officePlate
        ))
    }

    @Test func cityPlateIsLargeEnoughThatTheEngineCapBinds() {
        // A 2048×1152 junction bound first (step 25). An IE-sized district is
        // larger than the engine's 155% zoom-out, so the cap is GemRB's 27 and
        // the viewport still sits inside the plate — the BG:EE outdoor rule.
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
