import Testing
@testable import RainShadowCore

/// Holds the GemRB blit port (`IEBlitFlags`, `IEBlit`) to upstream's answers.
///
/// These are byte-exact integer shaders, so every expectation here is a number
/// computed from the quoted C++ rather than a tolerance. Where an answer looks
/// wrong — white tinting to 254, grey topping out at 189 — the test says why it
/// is upstream's answer, because those are the two that a later reader is most
/// likely to "correct".
struct IEBlitTests {
    private let opaqueWhite = IEColor(255, 255, 255, 255)

    // MARK: - Flag values

    /// A renumbered flag is invisible until it crosses a boundary — a shader
    /// uniform, a saved area, a comparison against upstream — so pin the values
    /// rather than trusting the declaration to be read carefully.
    @Test func flagValuesAreUpstreams() {
        #expect(IEBlitFlags.halftrans.rawValue == 2)
        #expect(IEBlitFlags.blended.rawValue == 8)
        #expect(IEBlitFlags.add.rawValue == 0x10)
        #expect(IEBlitFlags.mod.rawValue == 0x20)
        #expect(IEBlitFlags.mul.rawValue == 0x40)
        #expect(IEBlitFlags.colorMod.rawValue == 0x1000)
        #expect(IEBlitFlags.grey.rawValue == 0x8_0000)
        #expect(IEBlitFlags.sepia.rawValue == 0x0200_0000)
        #expect(IEBlitFlags.stencilGreen.rawValue == 0x0800_0000)
        #expect(IEBlitFlags.stencilDither.rawValue == 0x1000_0000)
    }

    /// `NONE = 0`, and an empty option set is how the port spells it.
    @Test func noFlagsIsZero() {
        #expect(IEBlitFlags([]).rawValue == 0)
    }

    // MARK: - ShaderTint

    /// `(255 * 255) >> 8` is 254, not 255. The engine's tint is a multiply with
    /// a truncating shift and it loses a step at full white; upstream lives with
    /// that by gating the tint behind `COLOR_MOD` instead of ever passing white.
    /// A port that rounded this to identity would disagree with the engine on
    /// every flagged-but-untinted sprite.
    @Test func tintingByWhiteIsNotIdentity() {
        var c = opaqueWhite
        IEBlit.shaderTint(opaqueWhite, &c)
        #expect(c == IEColor(254, 254, 254, 255))
    }

    @Test func tintingByBlackIsBlack() {
        var c = opaqueWhite
        IEBlit.shaderTint(IEColor(0, 0, 0, 255), &c)
        #expect(c == IEColor(0, 0, 0, 255))
    }

    /// Worked from the quoted arithmetic: `(128 * 200) >> 8 == 100`,
    /// `(64 * 200) >> 8 == 50`, `(255 * 200) >> 8 == 199`.
    @Test func tintingMultipliesAndTruncates() {
        var c = IEColor(200, 200, 200, 255)
        IEBlit.shaderTint(IEColor(128, 64, 255, 255), &c)
        #expect(c == IEColor(100, 50, 199, 255))
    }

    /// A multiply can only darken. This is the whole difference from the
    /// `colorBlendFactor` lerp it replaces, which brightens a dark pixel toward
    /// the tint instead.
    @Test func tintingNeverBrightensAChannel() {
        for value in stride(from: 0, through: 255, by: 17) {
            for tint in stride(from: 0, through: 255, by: 17) {
                var c = IEColor(UInt8(value), UInt8(value), UInt8(value), 255)
                IEBlit.shaderTint(IEColor(UInt8(tint), UInt8(tint), UInt8(tint), 255), &c)
                #expect(c.r <= UInt8(value))
            }
        }
    }

    @Test func tintingLeavesAlphaAlone() {
        var c = IEColor(200, 200, 200, 77)
        IEBlit.shaderTint(IEColor(10, 10, 10, 3), &c)
        #expect(c.a == 77)
    }

    // MARK: - ShaderGreyscale

    /// `255 >> 2` is 63, and `63 * 3` is 189 — upstream's own comment says "a is
    /// at most 189". The engine's white greys to 189, not 255, so the paused
    /// world is meaningfully darker than a desaturate. This is the expectation
    /// that fails if someone swaps in a `CIFilter` saturation of zero.
    @Test func greyscaleWhiteIs189NotWhite() {
        var c = opaqueWhite
        IEBlit.shaderGreyscale(&c)
        #expect(c == IEColor(189, 189, 189, 255))
    }

    @Test func greyscaleBlackIsBlack() {
        var c = IEColor(0, 0, 0, 255)
        IEBlit.shaderGreyscale(&c)
        #expect(c == IEColor(0, 0, 0, 255))
    }

    /// An unweighted average, not Rec. 709 luma: a saturated red and a saturated
    /// blue of equal magnitude grey to the same value. Under any perceptual
    /// metric they would not, so a "better" greyscale would be a different
    /// engine.
    @Test func greyscaleIsUnweightedNotLuma() {
        var red = IEColor(255, 0, 0, 255)
        var blue = IEColor(0, 0, 255, 255)
        IEBlit.shaderGreyscale(&red)
        IEBlit.shaderGreyscale(&blue)
        #expect(red == IEColor(63, 63, 63, 255))
        #expect(red == blue)
    }

    @Test func greyscaleLeavesAlphaAlone() {
        var c = IEColor(200, 100, 50, 42)
        IEBlit.shaderGreyscale(&c)
        #expect(c.a == 42)
    }

    // MARK: - ShaderSepia

    /// White: `avg == 189`, so `r = 210`, `g = 189`, `b = 157`.
    @Test func sepiaWhiteIsTheWarmCeiling() {
        var c = opaqueWhite
        IEBlit.shaderSepia(&c)
        #expect(c == IEColor(210, 189, 157, 255))
    }

    /// The `avg < 32 ? 0 : avg - 32` guard, and the fact that it is joined
    /// continuously by the subtraction: 31 clamps to 0, and 32 subtracts to 0
    /// as well, so 33 is the first non-zero blue.
    @Test func sepiaBlueClampsBelow32AndJoinsContinuouslyAt32() {
        // Channels chosen so the post-shift sum lands exactly on each avg.
        func blue(forAverage target: Int) -> UInt8 {
            var c = IEColor(UInt8(target * 4), 0, 0, 255)
            IEBlit.shaderSepia(&c)
            return c.b
        }
        #expect(blue(forAverage: 31) == 0)
        #expect(blue(forAverage: 32) == 0)
        #expect(blue(forAverage: 33) == 1)
    }

    /// The offsets are absolute bytes, not proportions, so the warm cast is
    /// strongest in the shadows: red runs 21 over grey at every level.
    @Test func sepiaRedIsAFixedOffsetOverGrey() {
        for value in stride(from: 0, through: 255, by: 15) {
            var grey = IEColor(UInt8(value), UInt8(value), UInt8(value), 255)
            var sepia = grey
            IEBlit.shaderGreyscale(&grey)
            IEBlit.shaderSepia(&sepia)
            #expect(sepia.r == grey.r + 21)
            #expect(sepia.g == grey.g)
        }
    }

    // MARK: - shade composition

    @Test func shadeIgnoresTheTintWithoutColorMod() {
        let c = IEColor(200, 200, 200, 255)
        #expect(IEBlit.shade(c, tint: IEColor(0, 0, 0, 255), flags: []) == c)
    }

    @Test func shadeAppliesTheTintWithColorMod() {
        let c = IEColor(200, 200, 200, 255)
        let shaded = IEBlit.shade(c, tint: IEColor(128, 128, 128, 255), flags: .colorMod)
        #expect(shaded == IEColor(100, 100, 100, 255))
    }

    /// `GREY` wins over `SEPIA` when both are set. Sepia's red would be 21 over
    /// the grey, so the two are trivially distinguishable.
    @Test func greyBeatsSepiaWhenBothAreSet() {
        let c = opaqueWhite
        let both = IEBlit.shade(c, tint: c, flags: [.grey, .sepia])
        let greyOnly = IEBlit.shade(c, tint: c, flags: .grey)
        #expect(both == greyOnly)
        #expect(both.r == 189)
    }

    /// The port applies tint and state shader in sequence where upstream's
    /// `RGBBlendingPipeline` fuses them into a single `>> 10`. Integer shifts
    /// compose — `(x >> 8) >> 2 == x >> 10` — so this must be exact equality
    /// across the whole channel range, not a near miss.
    @Test func sequentialShadeEqualsUpstreamsFusedShift() {
        for value in stride(from: 0, through: 255, by: 5) {
            for tintValue in stride(from: 0, through: 255, by: 5) {
                let c = IEColor(UInt8(value), UInt8(value), UInt8(value), 255)
                let tint = IEColor(UInt8(tintValue), UInt8(tintValue), UInt8(tintValue), 255)
                let ours = IEBlit.shade(c, tint: tint, flags: [.colorMod, .grey])

                // Upstream fused: (tint * c) >> 10 per channel, then summed.
                let fusedChannel = (value * tintValue) >> 10
                let fusedAverage = UInt8(fusedChannel * 3)
                #expect(ours.r == fusedAverage)
            }
        }
    }

    // MARK: - ApplyGlobalTint

    /// No global tint is `GetGlobalTint()` returning null: nothing moves, and in
    /// particular the flags do not gain `COLOR_MOD`.
    @Test func noGlobalTintChangesNothing() {
        var tint = IEColor(10, 20, 30, 40)
        var flags: IEBlitFlags = .blended
        IEBlit.applyGlobalTint(&tint, &flags, global: nil)
        #expect(tint == IEColor(10, 20, 30, 40))
        #expect(flags == .blended)
    }

    /// Upstream's asymmetry, and the half a tidy-up would delete: with no tint
    /// already in hand the global one **replaces** rather than seeds it, and
    /// forces alpha opaque.
    @Test func globalTintReplacesAndForcesOpaqueWithoutColorMod() {
        var tint = IEColor(10, 20, 30, 40)
        var flags: IEBlitFlags = .blended
        IEBlit.applyGlobalTint(&tint, &flags, global: IEColor(200, 100, 50, 7))
        #expect(tint == IEColor(200, 100, 50, 255))
        #expect(flags.contains(.colorMod))
        #expect(flags.contains(.blended))
    }

    /// With a lightmap tint already in hand the global one multiplies into it:
    /// `(200 * 128) >> 8 == 100`.
    @Test func globalTintMultipliesIntoAnExistingTint() {
        var tint = IEColor(200, 200, 200, 255)
        var flags: IEBlitFlags = [.blended, .colorMod]
        IEBlit.applyGlobalTint(&tint, &flags, global: IEColor(128, 128, 128, 255))
        #expect(tint == IEColor(100, 100, 100, 255))
    }
}
