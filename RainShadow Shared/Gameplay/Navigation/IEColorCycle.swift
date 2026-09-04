import CoreGraphics

/// The engine's shared two-colour pulse (GemRB `core/GUI/GUIAnimation.cpp`,
/// `core/GUI/GUIAnimation.h`).
///
/// GemRB keeps one process-wide `ColorCycle GlobalColorCycle(7)` so every
/// element that flashes — ground circles, the target reticle — flashes in step,
/// and advances it once per game tick from `Interface::Main`:
///
/// ```cpp
/// static const uint8_t ColorCycleSteps[] = { 6, 4, 2, 0, 2, 4, 6, 8 };
/// ColorCycle GlobalColorCycle(7);
///
/// void ColorCycle::AdvanceTime(tick_t time)
/// {
///     step = ColorCycleSteps[(time >> speed) & 7];
/// }
/// ```
///
/// The stored `step` is nothing but a cache of that expression, so there is no
/// state worth keeping here: sampling wall-clock milliseconds at the call site
/// reproduces the global exactly, keeps every caller in phase for free, and
/// leaves this `Sendable`.
enum IEColorCycle {
    /// `ColorCycleSteps`. Note it is not a triangle wave — the ramp down passes
    /// through 0 and the ramp up ends at 8, so the cycle rests a beat on the
    /// second colour and overshoots on the first.
    static let steps: [Int] = [6, 4, 2, 0, 2, 4, 6, 8]

    /// `GlobalColorCycle`'s shift. One step per 128 ms, eight steps per cycle,
    /// so the whole pulse takes 1024 ms.
    static let speed: UInt64 = 7

    /// `ColorCycle::AdvanceTime` folded into a query.
    static func step(atMilliseconds milliseconds: UInt64) -> Int {
        steps[Int((milliseconds >> speed) & 7)]
    }

    /// `ColorCycle::Blend`. At step 0 the answer is `c2`, at 8 it is `c1`; the
    /// alpha is taken from `c1` and never mixed, as upstream's comment says.
    ///
    /// ```cpp
    /// mix.a = c1.a;
    /// mix.r = (c1.r * step + c2.r * (8 - step)) >> 3;
    /// ```
    static func blend(_ c1: HighlightColor, _ c2: HighlightColor, step: Int) -> HighlightColor {
        let a = c1.byteComponents
        let b = c2.byteComponents
        return HighlightColor(
            redByte: (a.red * step + b.red * (8 - step)) >> 3,
            greenByte: (a.green * step + b.green * (8 - step)) >> 3,
            blueByte: (a.blue * step + b.blue * (8 - step)) >> 3,
            alphaByte: a.alpha
        )
    }
}

/// Byte-space access to `HighlightColor`.
///
/// The engine's `Color` is four `uint8_t`, and both the circle's dim
/// (`overColor.r = color.r >> 1`) and the cycle's blend are integer shifts on
/// those bytes. Doing that arithmetic in floats would round differently, so the
/// port converts, shifts, and converts back. The round trip is exact because
/// `HighlightColor(rgba:)` divides by 255.
extension HighlightColor {
    var byteComponents: (red: Int, green: Int, blue: Int, alpha: Int) {
        (
            Int((red * 255).rounded()),
            Int((green * 255).rounded()),
            Int((blue * 255).rounded()),
            Int((alpha * 255).rounded())
        )
    }

    init(redByte: Int, greenByte: Int, blueByte: Int, alphaByte: Int) {
        self.init(
            red: CGFloat(redByte) / 255,
            green: CGFloat(greenByte) / 255,
            blue: CGFloat(blueByte) / 255,
            alpha: CGFloat(alphaByte) / 255
        )
    }

    /// `Selectable::SetCircle`'s `overColor` — the selected colour at half
    /// intensity, alpha untouched.
    var halved: HighlightColor {
        let c = byteComponents
        return HighlightColor(
            redByte: c.red >> 1,
            greenByte: c.green >> 1,
            blueByte: c.blue >> 1,
            alphaByte: c.alpha
        )
    }
}
