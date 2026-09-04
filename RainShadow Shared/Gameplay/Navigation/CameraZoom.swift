import CoreGraphics

/// Player-controlled zoom band around the default play density.
///
/// `DefaultPlayZoom` owns the native-sprite calibration at 100%.
/// This owns the band the player may move through, and
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
///
/// The band is the engine's in **every** area, indoor and outdoor alike. There
/// is no per-plate ceiling: once the viewport outgrows the area,
/// `AreaViewport.clampedCenter` centres the map and lets black show, which is
/// what `MoveViewportTo` does. A `fitStep` used to narrow the band here so no
/// void could ever appear; it made the office unable to zoom out at all at 16:9
/// and start below 100% at 21:9, neither of which is the engine.
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
    /// for the current window (`DefaultPlayZoom.cameraVisibleHeight`).
    static func visibleHeight(base: CGFloat, step: Int) -> CGFloat {
        base * percent(forStep: step) / 100
    }
}
