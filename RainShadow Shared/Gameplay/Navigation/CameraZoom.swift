import CoreGraphics

/// Player-controlled zoom band around the default play density.
///
/// `DefaultPlayZoom` owns *where the camera sits by default* (BG:EE area view,
/// ~9% body-to-viewport). This owns the band the player may move through, and
/// it is BG:EE's, taken from GemRB's `GameControl`:
///
/// ```
/// unsigned int zoomLevel = 16;                    // 100%
/// unsigned int GetScalePercent() { return 20 + zoomLevel * 5; }
/// // OnMouseWheelScroll: "EEs have 27 zoom steps", clamped to 1…27
/// // SetScalePercent:    Clamp(level, 25u, 160u); zoomLevel = (value - 20) / 5;
/// ```
///
/// The step is an integer, not a float, and the stride is **five percentage
/// points, linear** — not a multiplicative ratio. One notch near 100% is a 5%
/// change; one notch near the zoom-in floor is a 20% change. That asymmetry is
/// the engine's, and reproducing it is the point.
///
/// `percent` means *world shown*, matching `Region::Scale(percent)`, which
/// multiplies the viewport rect's world width and height by `percent / 100` and
/// re-centres it. So a **higher** percent shows **more** world (zoomed out), and
/// 25% is a 4× magnification. Because `Region::Scale` re-centres, BG zooms about
/// the viewport centre and never about the cursor.
enum CameraZoom {
    /// BG:EE `zoomLevel` default. `percent(forStep: 16) == 100`.
    static let defaultStep = 16
    /// BG:EE's wheel clamp: `zoomLevel > 1` on the way in, `< 27` on the way out.
    static let engineStepRange: ClosedRange<Int> = 1...27
    /// `20 + step * 5`.
    static let percentOrigin: CGFloat = 20
    static let percentStride: CGFloat = 5
    /// `SetScalePercent`'s own clamp, which is one step wider than the wheel's on
    /// the zoom-out side (160% → step 28). Kept so `step(forPercent:)` reproduces
    /// the engine rather than a tidied version of it.
    static let settablePercentRange: ClosedRange<CGFloat> = 25...160

    /// World shown as a percentage of the default play density.
    static func percent(forStep step: Int) -> CGFloat {
        percentOrigin + CGFloat(step) * percentStride
    }

    /// GemRB `SetScalePercent`: clamp to 25…160, then integer-divide. 160 yields
    /// step 28, one past the wheel's ceiling — the engine's own off-by-one, not a
    /// typo here. Use `clamped(step:to:)` to land back inside a usable band.
    static func step(forPercent percent: CGFloat) -> Int {
        let value = min(max(percent, settablePercentRange.lowerBound), settablePercentRange.upperBound)
        return Int((value - percentOrigin) / percentStride)
    }

    static func clamped(step: Int, to range: ClosedRange<Int>) -> Int {
        min(max(step, range.lowerBound), range.upperBound)
    }

    /// Camera-visible world height at `step`, where `base` is the 100% height
    /// (`DefaultPlayZoom.cameraVisibleHeight`).
    static func visibleHeight(base: CGFloat, step: Int) -> CGFloat {
        base * percent(forStep: step) / 100
    }

    /// Largest step whose viewport still fits inside the painted plate.
    ///
    /// The Infinity Engine does not do this: `MoveViewportTo` centres the map
    /// once the viewport outgrows it (`if (viewport.w >= mapsize.w + 64)`) and
    /// lets black show around the edges. RainShadow does not accept that void —
    /// see `DefaultPlayZoomTests.officePlateFullyCoversTheViewportAtPlayDensity`
    /// — so the zoom-out ceiling is the smaller of BG:EE's 155% and what the
    /// plate can actually cover.
    ///
    /// - Parameters:
    ///   - base: visible world height at 100%.
    ///   - viewportAspect: view width ÷ view height. The ceiling is
    ///     aspect-dependent, so this must be evaluated against the live view size
    ///     rather than baked into a constant: the office is bound vertically at
    ///     16:9 and horizontally at 21:9.
    ///   - anchor: centre of the rect the camera is clamped inside — the same
    ///     rect the scene hands `updateCamera`. Testing the viewport from there
    ///     covers both cases with one rule. Where the clamp rect is *smaller*
    ///     than the viewport (the office painted room) the camera is pinned to
    ///     that centre and the test is exact. Where it is larger (a city
    ///     district) the viewport still fits inside the clamp rect, which is
    ///     itself inside the plate, so centring it there cannot be optimistic.
    ///   - plate: the painted extent that must stay covered. For the office this
    ///     is `worldBounds`, **not** `paintedRoomBounds` — the room rect is
    ///     smaller than the viewport and describes where the camera may go, not
    ///     what the art covers.
    static func fitStep(
        base: CGFloat,
        viewportAspect: CGFloat,
        anchor: CGPoint,
        plate: CGRect,
        within range: ClosedRange<Int> = engineStepRange
    ) -> Int {
        guard base > 0, viewportAspect > 0, plate.width > 0, plate.height > 0 else {
            return range.lowerBound
        }
        var step = range.upperBound
        while step > range.lowerBound {
            let height = visibleHeight(base: base, step: step)
            if fits(width: height * viewportAspect, height: height, anchor: anchor, plate: plate) {
                return step
            }
            step -= 1
        }
        return range.lowerBound
    }

    /// Sub-unit tolerance so a viewport that lands exactly on the plate edge is
    /// not rejected by accumulated `CGFloat` error.
    private static let fitEpsilon: CGFloat = 0.001

    private static func fits(
        width: CGFloat,
        height: CGFloat,
        anchor: CGPoint,
        plate: CGRect
    ) -> Bool {
        anchor.x - width / 2 >= plate.minX - fitEpsilon
            && anchor.x + width / 2 <= plate.maxX + fitEpsilon
            && anchor.y - height / 2 >= plate.minY - fitEpsilon
            && anchor.y + height / 2 <= plate.maxY + fitEpsilon
    }
}
