import CoreGraphics
import Testing
@testable import RainShadowCore

/// `GameControl::MoveViewportTo`'s clamp, held to the engine rather than to a
/// tidied version of it. The asymmetries are the assertions worth having: a
/// symmetric clamp passes a "does it stay near the map" test and fails these.
struct AreaViewportTests {
    /// A plain area at the origin, wide enough that a 400x300 viewport pans.
    private static let map = CGRect(x: 0, y: 0, width: 2_000, height: 1_500)
    private static let viewport = CGSize(width: 400, height: 300)

    private static func clamped(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        AreaViewport.clampedCenter(CGPoint(x: x, y: y), viewport: viewport, map: map)
    }

    @Test func aViewportInsideTheAreaIsLeftAlone() {
        let centre = Self.clamped(1_000, 750)
        #expect(centre == CGPoint(x: 1_000, y: 750))
    }

    @Test func horizontalOverflowIsSixtyFourOnBothSides() {
        // `p.x < -64 → p.x = -64` and `p.x + w >= W + 64 → p.x = W - w + 64`.
        let left = Self.clamped(-5_000, 750)
        #expect(left.x - Self.viewport.width / 2 == Self.map.minX - AreaViewport.overflow)
        let right = Self.clamped(5_000, 750)
        #expect(right.x + Self.viewport.width / 2 == Self.map.maxX + AreaViewport.overflow)
    }

    @Test func verticalOverflowIsOnTheFarEdgeOnly() {
        // The one that looks like a bug. Engine `p.y < 0` pins the map top flush
        // with no give; only the far edge gets `+ padding`. Engine-top is world
        // maxY, so the top edge lands exactly on maxY and the bottom edge
        // reaches 50 units below minY.
        let up = Self.clamped(1_000, 99_999)
        #expect(up.y + Self.viewport.height / 2 == Self.map.maxY)
        let down = Self.clamped(1_000, -99_999)
        #expect(down.y - Self.viewport.height / 2 == Self.map.minY - AreaViewport.farEdgePadding)
        // Stated as the asymmetry itself, so squaring the axes up fails here.
        #expect(AreaViewport.farEdgePadding != 0)
    }

    @Test func aViewportWiderThanTheAreaCentresTheMap() {
        // `if (viewport.w >= mapsize.w + 64) p.x = (mapsize.w - viewport.w) / 2`.
        let wide = CGSize(width: Self.map.width + AreaViewport.overflow, height: 300)
        let centre = AreaViewport.clampedCenter(
            CGPoint(x: 99_999, y: 750),
            viewport: wide,
            map: Self.map
        )
        #expect(centre.x == Self.map.midX)
    }

    @Test func aViewportTallerThanTheAreaCentresItFiftyUnitsOffTrueCentre() {
        // `p.y = (mapsize.h - viewport.h) / 2 + padding` — upstream biases the
        // centring to keep the map clear of the message window, and the bias
        // survives the y-flip as `map.midY - farEdgePadding`. Not a true centre,
        // and not a mistake here.
        let tall = CGSize(width: 400, height: Self.map.height + AreaViewport.farEdgePadding)
        let centre = AreaViewport.clampedCenter(
            CGPoint(x: 1_000, y: 99_999),
            viewport: tall,
            map: Self.map
        )
        #expect(centre.y == Self.map.midY - AreaViewport.farEdgePadding)
    }

    @Test func anAreaAwayFromTheOriginClampsInItsOwnSpace() {
        // RainShadow areas do not all start at zero — the office does not.
        let offset = OfficeInteriorScale.paintedRoomBounds
        #expect(offset.minX > 0)
        let small = CGSize(width: 200, height: 150)
        let left = AreaViewport.clampedCenter(
            CGPoint(x: -10_000, y: offset.midY),
            viewport: small,
            map: offset
        )
        #expect(abs((left.x - small.width / 2) - (offset.minX - AreaViewport.overflow)) < 0.000_1)
    }

    @Test func theOfficeAtTheWidestStepCentresAndShowsVoid() {
        // The accepted trade, as a number. At 155% and 16:9 the viewport is
        // larger than the painted room in both axes, so the clamp takes its
        // centring branches and the margin is black. The old `fitStep` refused
        // to let the player reach this at all.
        let room = OfficeInteriorScale.paintedRoomBounds
        let height = CameraZoom.visibleHeight(
            base: OfficeInteriorScale.cameraVisibleHeight(forSceneHeight: 1_152),
            step: CameraZoom.engineStepRange.upperBound
        )
        let widest = CGSize(width: height * 16 / 9, height: height)
        #expect(widest.width > room.width + AreaViewport.overflow)
        #expect(widest.height > room.height + AreaViewport.farEdgePadding)
        let centre = AreaViewport.clampedCenter(
            CGPoint(x: room.midX, y: room.midY),
            viewport: widest,
            map: room
        )
        #expect(centre.x == room.midX)
        #expect(centre.y == room.midY - AreaViewport.farEdgePadding)
    }

    @Test func aWardStillPansAtTheWidestStep() {
        // Inertness for the outdoor path: the band was already full there, and
        // a ward is larger than the 155% viewport, so it pans exactly as before
        // apart from the 64-unit overflow.
        let plate = CityDistrictDefinition.worldBounds
        let height = CameraZoom.visibleHeight(
            base: CityDistrictLayout.cameraVisibleHeight(forSceneHeight: 1_152),
            step: CameraZoom.engineStepRange.upperBound
        )
        let widest = CGSize(width: height * 16 / 9, height: height)
        #expect(widest.width < plate.width)
        #expect(widest.height < plate.height)
        let centre = AreaViewport.clampedCenter(
            CGPoint(x: plate.midX, y: plate.midY),
            viewport: widest,
            map: plate
        )
        #expect(centre == CGPoint(x: plate.midX, y: plate.midY))
    }

    @Test func anEmptyAreaLeavesTheCameraWhereItIs() {
        // `canMove = area != nullptr`: with no area the engine never clamps.
        let target = CGPoint(x: 12, y: 34)
        #expect(AreaViewport.clampedCenter(target, viewport: Self.viewport, map: .zero) == target)
    }
}
