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
    /// Selection-ring opacity so the underfoot ellipse does not neon against pavement.
    let selectionRingAlpha: CGFloat

    /// Dim desk-lamp office. The Infinity Engine tints sprites from the area
    /// lightmap, so a character in a dark room is visibly pulled into it; at
    /// the old 0.10 blend the neutral bake floated bright and warm over the
    /// dark floorboards. Slightly warm but *darker* than the bake, so Voss
    /// sits in the room's value range instead of on top of it.
    static let officeInterior = ActorSceneLighting(
        bodyTint: SKColor(red: 0.78, green: 0.73, blue: 0.66, alpha: 1),
        bodyBlend: 0.30,
        contactShadowAlphaScale: 1.0,
        selectionRingAlpha: 1.0
    )

    /// Rain-night exterior — cool slate pull that seats the coat in wet cobbles.
    static let cityNight = ActorSceneLighting(
        bodyTint: SKColor(red: 0.36, green: 0.44, blue: 0.56, alpha: 1),
        bodyBlend: 0.46,
        contactShadowAlphaScale: 1.18,
        selectionRingAlpha: 0.72
    )

    /// Daylight exterior — warm American-street pull. Default for outdoor wards;
    /// rain stays a weather overlay rather than a grade.
    static let cityDay = ActorSceneLighting(
        bodyTint: SKColor(red: 0.92, green: 0.88, blue: 0.78, alpha: 1),
        bodyBlend: 0.22,
        contactShadowAlphaScale: 0.95,
        selectionRingAlpha: 0.88
    )

    /// Untinted presentation (debug / identity checks).
    static let neutral = ActorSceneLighting(
        bodyTint: .white,
        bodyBlend: 0,
        contactShadowAlphaScale: 1.0,
        selectionRingAlpha: 1.0
    )
}
