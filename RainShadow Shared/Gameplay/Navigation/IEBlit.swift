import CoreGraphics
import Foundation

/// The engine's blit flags (GemRB `core/Sprite2D.h`, `enum BlitFlags : uint32_t`).
///
/// Only the members RainShadow actually draws with are ported. The values are
/// upstream's, **not** renumbered to close the gaps: a flag that is missing here
/// is missing, not renamed, and adding one later must take the upstream value so
/// a `rawValue` never means two different things across the two codebases.
///
/// ```cpp
/// enum BlitFlags : uint32_t {
///     NONE = 0,
///     HALFTRANS = 2,
///     BLENDED = 8,
///     ADD = 0x10,
///     MOD = 0x20,
///     MUL = 0x40,
///     COLOR_MOD = 0x1000,
///     GREY = 0x80000,
///     SEPIA = 0x02000000,
///     STENCIL_GREEN = 0x08000000,
///     STENCIL_DITHER = 0x10000000,
/// };
/// ```
///
/// Deliberately not ported: `ONE_MINUS_DST`, `DST`, `SRC`, `BLEND_MASK`,
/// `ALPHA_MOD`, `MIRRORX`, `MIRRORY`, `STENCIL_ALPHA`, `STENCIL_RED`,
/// `STENCIL_BLUE`, `STENCIL_MASK`. The mirror flags are SpriteKit's `xScale`,
/// and the unported stencil channels belong to the blit paths RainShadow has no
/// equivalent of — see ``AreaWallStencil`` for which channels we do write.
struct IEBlitFlags: OptionSet, Hashable, Sendable {
    let rawValue: UInt32

    init(rawValue: UInt32) {
        self.rawValue = rawValue
    }

    /// `BlitFlags::HALFTRANS`. Black at this flag is the fog's alpha 128, which
    /// is why ``FogGrid`` cites it too.
    static let halftrans = IEBlitFlags(rawValue: 2)
    static let blended = IEBlitFlags(rawValue: 8)
    static let add = IEBlitFlags(rawValue: 0x10)
    static let mod = IEBlitFlags(rawValue: 0x20)
    static let mul = IEBlitFlags(rawValue: 0x40)
    /// The flag that turns the tint argument on. `BlitGameSprite` tests for this
    /// rather than passing an identity tint, and ``IEBlit/shaderTint(_:_:)``
    /// explains why it has to.
    static let colorMod = IEBlitFlags(rawValue: 0x1000)
    static let grey = IEBlitFlags(rawValue: 0x8_0000)
    static let sepia = IEBlitFlags(rawValue: 0x0200_0000)
    static let stencilGreen = IEBlitFlags(rawValue: 0x0800_0000)
    static let stencilDither = IEBlitFlags(rawValue: 0x1000_0000)
}

/// The engine's per-pixel shaders (GemRB `core/Video/Pixels.h`).
///
/// These are the three free functions `RGBBlendingPipeline` runs over a source
/// pixel before it blends it, and they are the whole of "what colour is this
/// sprite in this room" once ``IEPalette`` has answered "what colour is this
/// index". `Map::DrawMap` picks the tint from the area lightmap and the flags
/// from the actor's state:
///
/// ```cpp
/// Color baseTint = area->GetLighting(actor->Pos);
/// Color tint(baseTint);
/// game->ApplyGlobalTint(tint, flags);
/// actor->Draw(viewport, baseTint, tint, flags | BlitFlags::BLENDED);
/// ```
///
/// The arithmetic is integer and the rounding is load-bearing, so the port keeps
/// bytes rather than working in floats and converting — the same reasoning
/// ``IEColorCycle`` records for its shifts.
enum IEBlit {
    /// `ShaderTint`.
    ///
    /// ```cpp
    /// inline void ShaderTint(const Color& tint, Color& c)
    /// {
    ///     c.r = (tint.r * c.r) >> 8;
    ///     c.g = (tint.g * c.g) >> 8;
    ///     c.b = (tint.b * c.b) >> 8;
    /// }
    /// ```
    ///
    /// **This is a multiply, not a blend toward a colour.** A lerp brightens a
    /// dark pixel toward the tint; this can only ever darken one, which is what
    /// puts a character into an unlit room instead of on top of it.
    ///
    /// It is also not identity at full white: `(255 * 255) >> 8` is 254, so
    /// tinting by white darkens every channel by one step. That is not a bug to
    /// correct — it is why upstream gates the tint behind `COLOR_MOD` rather
    /// than passing an identity tint, and a port that "fixed" it to 255 would
    /// disagree with the engine on every untinted-but-flagged sprite.
    ///
    /// Alpha is untouched, here and in both shaders below.
    static func shaderTint(_ tint: IEColor, _ c: inout IEColor) {
        c.r = UInt8((Int(tint.r) * Int(c.r)) >> 8)
        c.g = UInt8((Int(tint.g) * Int(c.g)) >> 8)
        c.b = UInt8((Int(tint.b) * Int(c.b)) >> 8)
    }

    /// `ShaderGreyscale`.
    ///
    /// ```cpp
    /// inline void ShaderGreyscale(Color& c)
    /// {
    ///     c.r >>= 2;
    ///     c.g >>= 2;
    ///     c.b >>= 2;
    ///     uint8_t avg = c.r + c.g + c.b;
    ///     c.r = c.g = c.b = avg;
    /// }
    /// ```
    ///
    /// The sum of three `>> 2` channels peaks at 189, so the engine's grey tops
    /// out well below white and is **darker than a luma desaturate**. A
    /// `CIFilter` saturation of zero is therefore not a substitute for this, and
    /// swapping one in is the obvious-looking change that would quietly stop
    /// matching the engine.
    ///
    /// It is also an unweighted average, not Rec. 709 luma: a saturated red and
    /// a saturated blue of the same magnitude grey to the same value here and
    /// would not under any perceptual metric.
    static func shaderGreyscale(_ c: inout IEColor) {
        c.r >>= 2
        c.g >>= 2
        c.b >>= 2
        let avg = UInt8(Int(c.r) + Int(c.g) + Int(c.b))
        c.r = avg
        c.g = avg
        c.b = avg
    }

    /// `ShaderSepia`.
    ///
    /// ```cpp
    /// inline void ShaderSepia(Color& c)
    /// {
    ///     c.r >>= 2;
    ///     c.g >>= 2;
    ///     c.b >>= 2;
    ///     uint8_t avg = c.r + c.g + c.b;
    ///     c.r = avg + 21; // can't overflow, since a is at most 189
    ///     c.g = avg;
    ///     c.b = avg < 32 ? 0 : avg - 32;
    /// }
    /// ```
    ///
    /// The `21` and the `32` are absolute byte offsets, not proportions, so the
    /// warm cast is strongest in the shadows and washes out in the highlights.
    /// Upstream's own comment carries the 189 bound that keeps `avg + 21` inside
    /// a byte; the `avg < 32` guard is the matching underflow clamp.
    static func shaderSepia(_ c: inout IEColor) {
        c.r >>= 2
        c.g >>= 2
        c.b >>= 2
        let avg = UInt8(Int(c.r) + Int(c.g) + Int(c.b))
        c.r = avg + 21
        c.g = avg
        c.b = avg < 32 ? 0 : avg - 32
    }

    /// `RGBBlendingPipeline`'s shade stage: tint first, then the state shader.
    ///
    /// Upstream fuses the two when both apply — the pipeline adds 2 to the tint
    /// shift for `GREYSCALE` and `SEPIA` and averages the already-shifted
    /// channels, so it does `(tint * c) >> 10` in one step. Applying them in
    /// sequence here is **exactly** equivalent rather than merely close, because
    /// integer shifts compose: `(x >> 8) >> 2 == x >> 10` for non-negative `x`.
    /// Sequential is kept because it lets each shader be read against its own
    /// upstream function.
    ///
    /// `GREY` wins over `SEPIA` when both are set, as upstream does.
    static func shade(_ c: IEColor, tint: IEColor, flags: IEBlitFlags) -> IEColor {
        var out = c
        if flags.contains(.colorMod) {
            shaderTint(tint, &out)
        }
        if flags.contains(.grey) {
            shaderGreyscale(&out)
        } else if flags.contains(.sepia) {
            shaderSepia(&out)
        }
        return out
    }

    /// `Game::ApplyGlobalTint`.
    ///
    /// ```cpp
    /// void Game::ApplyGlobalTint(Color& tint, BlitFlags& flags) const
    /// {
    ///     const Color* globalTint = GetGlobalTint();
    ///     if (globalTint) {
    ///         if (flags & BlitFlags::COLOR_MOD) {
    ///             ShaderTint(*globalTint, tint);
    ///         } else {
    ///             flags |= BlitFlags::COLOR_MOD;
    ///             tint = *globalTint;
    ///             tint.a = 255;
    ///         }
    ///     }
    /// }
    /// ```
    ///
    /// Note the asymmetry, which is upstream's and is easy to "tidy" away: when
    /// a lightmap tint is already in hand the global one multiplies into it, but
    /// when there is none the global one **replaces** rather than seeds it, and
    /// forces alpha opaque. `nil` is `GetGlobalTint()` returning null.
    static func applyGlobalTint(
        _ tint: inout IEColor,
        _ flags: inout IEBlitFlags,
        global: IEColor?
    ) {
        guard let global else { return }
        if flags.contains(.colorMod) {
            shaderTint(global, &tint)
        } else {
            flags.insert(.colorMod)
            tint = global
            tint.a = 255
        }
    }
}

extension IEColor {
    /// The tint that means "no tint". Note this is *not* an identity multiplier
    /// — see ``IEBlit/shaderTint(_:_:)`` — which is why the flag, not the value,
    /// is what decides whether a tint is applied at all.
    static let opaqueWhite = IEColor(255, 255, 255, 255)
}

extension AreaLightSample {
    /// `Map::GetLighting`'s answer in the engine's byte colour.
    ///
    /// `AreaLightMap` samples in 0...1 because it bilinearly interpolates and
    /// that is the natural space to do it in; the engine reads whole bytes out
    /// of `LM.BMP` and tints with them. This is the conversion between the two,
    /// and it is the last point at which the value is not an engine byte.
    var ieColor: IEColor {
        func byte(_ value: CGFloat) -> UInt8 {
            UInt8(max(0, min(255, (value * 255).rounded())))
        }
        return IEColor(byte(red), byte(green), byte(blue), 255)
    }
}
