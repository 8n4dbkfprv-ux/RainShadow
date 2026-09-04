import SpriteKit

/// Per-scene grade applied to neutral-baked actor sprites at runtime.
///
/// Character atlases stay one neutral light rig (GDD §5.3 / §5.5). Scenes pull
/// them into the room or street with a cool/warm body tint, blend weight, and
/// contact-shadow scale — no per-frame relight and no duplicate walk sheets.
struct ActorSceneLighting: Sendable {
    /// Target color mixed into body textures via `colorBlendFactor`.
    let bodyTint: SKColor
    /// 0 = full baked texture, 1 = solid tint (alpha still from texture).
    let bodyBlend: CGFloat
    /// Multiplies the kind’s standing contact-shadow alpha (wet night denser).
    let contactShadowAlphaScale: CGFloat

    /// Dim desk-lamp office. The Infinity Engine tints sprites from the area
    /// lightmap, so a character in a dark room is visibly pulled into it; at
    /// the old 0.10 blend the neutral bake floated bright and warm over the
    /// dark floorboards. Slightly warm but *darker* than the bake, so Voss
    /// sits in the room's value range instead of on top of it.
    static let officeInterior = ActorSceneLighting(
        bodyTint: SKColor(red: 0.78, green: 0.73, blue: 0.66, alpha: 1),
        bodyBlend: 0.30,
        contactShadowAlphaScale: 1.0
    )

    /// Rain-night exterior — cool slate pull that seats the coat in wet cobbles.
    static let cityNight = ActorSceneLighting(
        bodyTint: SKColor(red: 0.36, green: 0.44, blue: 0.56, alpha: 1),
        bodyBlend: 0.46,
        contactShadowAlphaScale: 1.18
    )

    /// Daylight exterior — warm American-street pull. Default for outdoor wards;
    /// rain stays a weather overlay rather than a grade.
    static let cityDay = ActorSceneLighting(
        bodyTint: SKColor(red: 0.92, green: 0.88, blue: 0.78, alpha: 1),
        bodyBlend: 0.22,
        contactShadowAlphaScale: 0.95
    )

    /// Untinted presentation (debug / identity checks).
    static let neutral = ActorSceneLighting(
        bodyTint: .white,
        bodyBlend: 0,
        contactShadowAlphaScale: 1.0
    )
}

extension ActorSceneLighting {
    /// The authored grade as an engine tint, for `Game::ApplyGlobalTint`.
    ///
    /// **This is an adaptation, not a transliteration.** Upstream has no blend
    /// weight, because its global tint *is* a multiplier and is authored as one.
    /// `bodyBlend` exists here only because the grade used to be applied through
    /// SpriteKit's `colorBlendFactor`, which interpolates toward a colour rather
    /// than multiplying by it. Folding the weight into the tint — interpolating
    /// from white toward ``bodyTint`` — keeps the authored knob meaningful while
    /// making the operation a true multiply. Re-authoring the three presets as
    /// direct multipliers and deleting `bodyBlend` would be closer to upstream;
    /// it would also throw away three hand-tuned grades, so it is a separate
    /// art decision rather than part of the port.
    ///
    /// `nil` is `GetGlobalTint()` returning null. A zero blend must not become a
    /// white tint: white is not an identity multiplier (`(255 * 255) >> 8` is
    /// 254), so tinting by it would darken every sprite by one step per channel
    /// for no reason. Upstream's answer to "no grade" is no tint at all.
    var globalTint: IEColor? {
        guard bodyBlend > 0 else { return nil }
        let full = IEColor(bodyTint)
        func mixed(_ channel: UInt8) -> UInt8 {
            let value = 255 - (255 - CGFloat(channel)) * bodyBlend
            return UInt8(max(0, min(255, value.rounded())))
        }
        return IEColor(mixed(full.r), mixed(full.g), mixed(full.b), 255)
    }
}
