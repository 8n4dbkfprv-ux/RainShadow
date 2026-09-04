import SpriteKit

@MainActor
enum RainSystem {
    static func makeEmitter(
        width: CGFloat,
        height: CGFloat,
        birthRate: CGFloat,
        speed: CGFloat,
        scale: CGFloat,
        alpha: CGFloat
    ) -> SKEmitterNode {
        let emitter = SKEmitterNode()
        emitter.particleTexture = GameArt.rainStreakTexture()
        emitter.particleBirthRate = birthRate
        emitter.particleLifetime = max(1.0, height / speed * 1.3)
        emitter.particleLifetimeRange = 0.35
        emitter.particlePositionRange = CGVector(dx: width, dy: 0)
        emitter.emissionAngle = -.pi / 2 - 0.12
        emitter.emissionAngleRange = 0.035
        emitter.particleSpeed = speed
        emitter.particleSpeedRange = speed * 0.16
        emitter.xAcceleration = -22
        emitter.particleAlpha = alpha
        emitter.particleAlphaRange = alpha * 0.35
        emitter.particleScale = scale
        emitter.particleScaleRange = scale * 0.22
        emitter.particleColor = SKColor(red: 0.66, green: 0.76, blue: 0.9, alpha: 1)
        emitter.particleColorBlendFactor = 1
        emitter.particleBlendMode = .add
        emitter.advanceSimulationTime(1.5)
        return emitter
    }
}

