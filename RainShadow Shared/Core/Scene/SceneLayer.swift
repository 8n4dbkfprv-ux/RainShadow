import SpriteKit

enum SceneLayer: CGFloat {
    case background = -10_000
    case floorEffects = -9_000
    case rearFixtures = -5_000
    case depthWorld = 1_000
    case occlusion = 5_000
    case weather = 7_000
    case cinematic = 8_000
    case hud = 10_000
}

