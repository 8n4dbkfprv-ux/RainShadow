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

    /// Warm desk-lamp office — light grade so the neutral bake stays readable.
    static let officeInterior = ActorSceneLighting(
        bodyTint: SKColor(red: 1.0, green: 0.96, blue: 0.90, alpha: 1),
        bodyBlend: 0.10,
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

    /// Untinted presentation (debug / identity checks).
    static let neutral = ActorSceneLighting(
        bodyTint: .white,
        bodyBlend: 0,
        contactShadowAlphaScale: 1.0,
        selectionRingAlpha: 1.0
    )
}
