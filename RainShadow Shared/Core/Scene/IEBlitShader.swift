import SpriteKit

/// ``IEBlit``'s pixel shaders as an `SKShader`, for the sprites SpriteKit draws.
///
/// `IEBlit` is the readable, testable copy of `core/Video/Pixels.h` and this is
/// the same three functions again in GLSL, because a fragment shader is the only
/// place SpriteKit lets us touch a pixel. The correspondence is line by line and
/// is called out in the source below; `IEBlitTests` holds the Swift copy to
/// upstream, and this file is held to the Swift copy by inspection plus the
/// in-app captures listed in the render-pipeline notes. Change one, change both.
///
/// **Three deliberate deviations from a literal transliteration**, each forced:
///
/// - **Flags are separate float toggles, not a packed bitfield.** SpriteKit
///   compiles a GLSL ES 1.0 subset, which has no bitwise operators at all, so
///   `flags & BlitFlags::GREY` cannot be written. `IEBlitFlags` stays the
///   authority and ``uniforms(tint:flags:alpha:)`` unpacks it at the boundary.
/// - **The shader works in byte space.** Upstream shifts `uint8_t`; a float
///   `* 0.25` is not `>> 2`, because the shift truncates. Every channel is
///   scaled to 0...255, floored, operated on, and scaled back, so the answers are
///   the integer ones `IEBlit` produces rather than something within a rounding
///   error of them.
/// - **Alpha is un-premultiplied first.** `SKTexture` pixels are premultiplied;
///   the engine's `Color` is straight. Tint and greyscale are linear and would
///   survive the difference, but sepia's `+ 21` and `- 32` are absolute byte
///   offsets and would land in the wrong place on a partially transparent pixel.
///   Un-premultiplying costs a divide and removes the whole class of bug.
///
/// **SpriteKit's opacity contract, measured rather than assumed.** Three facts
/// decide how this shader has to be written, and the middle one is a trap:
///
/// 1. `SKDefaultShading()` returns **premultiplied** RGBA — a white texel at
///    alpha 128 comes back with `.r == 128`, not 255.
/// 2. It **already includes the node's `alpha`** — a node at `alpha = 0.5` over
///    an opaque texture yields `texel.a == 0.5`.
/// 3. SpriteKit does **not** apply node `alpha` to the shader's *output*. A
///    shader that writes a constant `vec4(1, 0, 0, 1)` renders fully opaque red
///    at `alpha = 0.5`.
///
/// Together those mean node opacity reaches us through `texel.a` and nowhere
/// else, so this shader must carry `texel.a` through to `gl_FragColor` — which
/// it does — and must **not** also take an opacity uniform. An earlier draft had
/// one; it would have multiplied every fade in twice. `node.alpha` remains the
/// single opacity control, exactly as it is for an unshaded sprite.
enum IEBlitShader {
    // MARK: - Uniform names

    enum Uniform {
        static let tint = "u_ie_tint"
        static let colorMod = "u_ie_color_mod"
        static let grey = "u_ie_grey"
        static let sepia = "u_ie_sepia"
        /// The baked wall stencil (`Map::DrawStencil`'s buffer).
        static let stencil = "u_ie_stencil"
        /// Whether this sprite is stencilled at all — `SetDrawingStencilForScriptable`
        /// returning `BlitFlags::NONE` for an object no wall stands in front of.
        static let stencilOn = "u_ie_stencil_on"
        /// Maps `v_tex_coord` straight onto stencil UV: `xy` is the sprite's
        /// lower-left corner in stencil space, `zw` its span. One uniform instead
        /// of a world origin and size, because the shader only ever needs the
        /// composed mapping.
        static let stencilMap = "u_ie_stencil_map"
    }

    // MARK: - Source

    /// The three shaders, in `RGBBlendingPipeline`'s order: tint, then the state
    /// shader. `GREY` wins over `SEPIA`, as upstream does.
    static let source = """
    void main() {
        vec4 texel = SKDefaultShading();

        // Un-premultiply to the engine's straight-alpha Color.
        float alpha = texel.a;
        vec3 straight = alpha > 0.0 ? texel.rgb / alpha : vec3(0.0);

        // Byte space: upstream's operands are uint8_t and its shifts truncate.
        vec3 c = floor(straight * 255.0 + 0.5);

        // ShaderTint: c.r = (tint.r * c.r) >> 8;
        // A shift by 8 is a divide by 256, not by 255 — which is why tinting by
        // white gives 254 rather than 255. Keep the 256.
        if (u_ie_color_mod > 0.5) {
            vec3 t = floor(u_ie_tint.rgb * 255.0 + 0.5);
            c = floor(t * c / 256.0);
        }

        if (u_ie_grey > 0.5) {
            // ShaderGreyscale: c >>= 2; avg = r + g + b; r = g = b = avg;
            c = floor(c / 4.0);
            float avg = c.r + c.g + c.b;
            c = vec3(avg);
        } else if (u_ie_sepia > 0.5) {
            // ShaderSepia: r = avg + 21; g = avg; b = avg < 32 ? 0 : avg - 32;
            c = floor(c / 4.0);
            float avg = c.r + c.g + c.b;
            c = vec3(avg + 21.0, avg, avg < 32.0 ? 0.0 : avg - 32.0);
        }

        // `BlitFlags::STENCIL_DITHER`. `Map::SetDrawingStencilForScriptable`
        // returns it for an object standing behind a covering wall, and the
        // stencil decides per pixel rather than per object — which is the whole
        // difference from the uniform alpha this replaced.
        if (u_ie_stencil_on > 0.5) {
            vec2 suv = u_ie_stencil_map.xy + v_tex_coord * u_ie_stencil_map.zw;
            if (suv.x >= 0.0 && suv.x <= 1.0 && suv.y >= 0.0 && suv.y <= 1.0) {
                vec4 s = texture2D(u_ie_stencil, suv);
                // Green is WF_COVERANIMS: non-zero means covering mass is in
                // front of this pixel. Red says how: 0x80 (WF_DITHER) shows the
                // actor through, 0xFF hides outright.
                if (s.g > 0.0) {
                    vec2 p = floor(gl_FragCoord.xy);
                    // stencilcol.a is 0x80 — a 50% screen-space checker, which is
                    // why the basis is the fragment and not the mask cell. Tied
                    // to the mask instead, the stipple would coarsen with the
                    // camera and read as texture rather than transparency.
                    float checker = mod(p.x + p.y, 2.0);
                    float hide = s.r > 0.75 ? 1.0 : checker;
                    alpha = alpha * (1.0 - hide);
                }
            }
        }

        // Back to unit range and re-premultiplied. `alpha` already carries the
        // node's opacity, so nothing further is applied to it here.
        gl_FragColor = vec4((c / 255.0) * alpha, alpha);
    }
    """

    /// A 1x1 all-zero mask, bound whenever no real stencil is.
    ///
    /// Not `nil`: an unbound sampler makes SpriteKit fall back to default
    /// shading for the whole program, which shows up as *the tint silently not
    /// applying* rather than as an error. Binding a blank costs one texel and
    /// keeps the failure mode impossible.
    static let blankStencil: SKTexture = {
        let texture = SKTexture(
            data: Data([0, 0, 0, 0]),
            size: CGSize(width: 1, height: 1)
        )
        texture.filteringMode = .nearest
        return texture
    }()

    // MARK: - Construction

    /// One shader instance per sprite. `SKShader` caches its compiled program by
    /// source, so this is cheap to call per node, but uniforms live on the
    /// shader — two sprites that share an instance share a tint.
    static func make(tint: IEColor, flags: IEBlitFlags) -> SKShader {
        let shader = SKShader(source: source)
        shader.uniforms = uniforms(tint: tint, flags: flags)
        return shader
    }

    /// Unpack ``IEBlitFlags`` into the float toggles the GLSL subset can test.
    static func uniforms(tint: IEColor, flags: IEBlitFlags) -> [SKUniform] {
        [
            SKUniform(name: Uniform.tint, vectorFloat4: tint.vectorFloat4),
            SKUniform(name: Uniform.colorMod, float: flags.contains(.colorMod) ? 1 : 0),
            SKUniform(name: Uniform.grey, float: flags.contains(.grey) ? 1 : 0),
            SKUniform(name: Uniform.sepia, float: flags.contains(.sepia) ? 1 : 0),
            SKUniform(name: Uniform.stencil, texture: blankStencil),
            SKUniform(name: Uniform.stencilOn, float: 0),
            SKUniform(name: Uniform.stencilMap, vectorFloat4: vector_float4(0, 0, 1, 1))
        ]
    }

    /// Point this sprite's stencil lookup at the baked mask.
    ///
    /// `spriteWorldRect` is the sprite's own footprint in world space and
    /// `stencilFrame` the mask's, so the composed mapping takes `v_tex_coord`
    /// directly to stencil UV without the shader knowing about world units.
    ///
    /// Passing `nil` is `SetDrawingStencilForScriptable` returning
    /// `BlitFlags::NONE` — no wall stands in front of this object, so it draws
    /// unmasked. That is the common case and it costs one uniform write.
    static func updateStencil(
        _ shader: SKShader,
        texture: SKTexture?,
        spriteWorldRect: CGRect,
        stencilFrame: CGRect
    ) {
        guard let texture,
              stencilFrame.width > 0,
              stencilFrame.height > 0,
              spriteWorldRect.width > 0,
              spriteWorldRect.height > 0
        else {
            shader.uniformNamed(Uniform.stencil)?.textureValue = blankStencil
            shader.uniformNamed(Uniform.stencilOn)?.floatValue = 0
            return
        }
        shader.uniformNamed(Uniform.stencil)?.textureValue = texture
        shader.uniformNamed(Uniform.stencilOn)?.floatValue = 1
        shader.uniformNamed(Uniform.stencilMap)?.vectorFloat4Value = vector_float4(
            Float((spriteWorldRect.minX - stencilFrame.minX) / stencilFrame.width),
            Float((spriteWorldRect.minY - stencilFrame.minY) / stencilFrame.height),
            Float(spriteWorldRect.width / stencilFrame.width),
            Float(spriteWorldRect.height / stencilFrame.height)
        )
    }

    /// Update an existing shader in place. Per-frame path: an actor's lightmap
    /// tint changes on every step, and rebuilding the shader would recompile
    /// nothing but would churn uniform storage each tick.
    static func update(_ shader: SKShader, tint: IEColor, flags: IEBlitFlags) {
        shader.uniformNamed(Uniform.tint)?.vectorFloat4Value = tint.vectorFloat4
        shader.uniformNamed(Uniform.colorMod)?.floatValue = flags.contains(.colorMod) ? 1 : 0
        shader.uniformNamed(Uniform.grey)?.floatValue = flags.contains(.grey) ? 1 : 0
        shader.uniformNamed(Uniform.sepia)?.floatValue = flags.contains(.sepia) ? 1 : 0
    }
}

extension IEColor {
    /// The engine's four bytes as the unit-range vector a uniform takes. The
    /// shader scales back to bytes immediately; carrying units across the
    /// boundary is only because `SKUniform` has no byte vector.
    var vectorFloat4: vector_float4 {
        vector_float4(
            Float(r) / 255,
            Float(g) / 255,
            Float(b) / 255,
            Float(a) / 255
        )
    }

    /// Build from a SpriteKit colour, for the authored grades in
    /// ``ActorSceneLighting`` that have no engine origin.
    init(_ color: SKColor) {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        #if canImport(AppKit)
        let resolved = color.usingColorSpace(.sRGB) ?? color
        resolved.getRed(&r, green: &g, blue: &b, alpha: &a)
        #else
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        #endif
        self.init(
            UInt8((r * 255).rounded()),
            UInt8((g * 255).rounded()),
            UInt8((b * 255).rounded()),
            UInt8((a * 255).rounded())
        )
    }
}
