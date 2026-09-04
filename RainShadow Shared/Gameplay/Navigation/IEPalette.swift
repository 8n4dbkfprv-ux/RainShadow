import Foundation

/// A palette entry (GemRB `includes/RGBAColor.h`, `Color`).
///
/// Stored as four bytes in the engine's order so a palette can be memcpy'd
/// around; the port keeps the same shape because `SetupPaperdollColours` copies
/// runs of entries by range and the arithmetic has to line up.
struct IEColor: Equatable, Hashable, Sendable {
    var r: UInt8
    var g: UInt8
    var b: UInt8
    var a: UInt8

    init(_ r: UInt8, _ g: UInt8, _ b: UInt8, _ a: UInt8 = 255) {
        self.r = r
        self.g = g
        self.b = b
        self.a = a
    }

    /// `Palette::Colors buffer;` default-constructs to transparent black.
    static let transparentBlack = IEColor(0, 0, 0, 0)
}

/// The engine's 256-entry palette (GemRB `core/Palette.cpp`, `core/Palette.h`).
///
/// In the Infinity Engine the palette *is* the sprite's colour: a frame stores
/// 8-bit indices and nothing regrades them afterwards. Two indices are spoken
/// for — 0 is the colour key and 1 is the shadow — and everything above them is
/// material shades laid out by ``IEPaperdollColours``.
struct IEPalette: Equatable, Sendable {
    /// BAM v1's transparent index.
    static let colorKeyIndex = 0
    /// BAM v1's shadow index. Half-transed at draw, not at bake.
    static let shadowIndex = 1

    private(set) var colors: [IEColor]

    init() {
        colors = Array(repeating: .transparentBlack, count: 256)
    }

    init(colors: [IEColor]) {
        precondition(colors.count == 256, "a palette is 256 entries")
        self.colors = colors
    }

    subscript(index: Int) -> IEColor {
        get { colors[index] }
        set { colors[index] = newValue }
    }

    /// `Palette::Palette(const Color& color, const Color& back)`.
    ///
    /// ```cpp
    /// colors[0] = Color(0, 0xff, 0, 0);
    /// for (size_t i = 1; i < colors.size(); i++) {
    ///     float_t p = i / 255.0f;
    ///     colors[i].r = std::min<int>(back.r * (1 - p) + color.r * p, 255);
    ///     colors[i].g = std::min<int>(back.g * (1 - p) + color.g * p, 255);
    ///     colors[i].b = std::min<int>(back.b * (1 - p) + color.b * p, 255);
    ///     colors[i].a = 0xff;
    /// }
    /// ```
    ///
    /// `std::min<int>` converts the float to `int` *before* the comparison, so
    /// the blend truncates toward zero rather than rounding. The midpoint of a
    /// 100→200 ramp is 150, not 151. That one-count difference is the whole
    /// distance between a port and a lookalike, so it is reproduced here rather
    /// than tidied into a `rounded()`.
    init(color: IEColor, back: IEColor) {
        self.init()
        colors[0] = IEColor(0, 0xFF, 0, 0)
        for i in 1..<colors.count {
            let p = Float(i) / Float(255.0)
            func blend(_ from: UInt8, _ to: UInt8) -> UInt8 {
                UInt8(min(Int(Float(from) * (1 - p) + Float(to) * p), 255))
            }
            colors[i] = IEColor(
                blend(back.r, color.r),
                blend(back.g, color.g),
                blend(back.b, color.b),
                0xFF
            )
        }
    }

    /// `Palette::CopyColors`.
    mutating func copyColors(_ buffer: [IEColor]) {
        precondition(buffer.count == 256, "a palette is 256 entries")
        colors = buffer
    }

    /// `void Palette::TranslucentShadowColor(bool enable)`.
    ///
    /// ```cpp
    /// auto shadowColor = colors[1];
    /// shadowColor.a = enable ? 128 : 255;
    /// SetColor(1, shadowColor);
    /// ```
    ///
    /// The shadow is a palette entry, not a separate sprite. That is why the
    /// engine never needs a contact-shadow node: a frame's own index-1 pixels
    /// are its shadow, and this is the only thing that makes them translucent.
    mutating func translucentShadowColor(_ enable: Bool) {
        colors[Self.shadowIndex].a = enable ? 128 : 255
    }
}
