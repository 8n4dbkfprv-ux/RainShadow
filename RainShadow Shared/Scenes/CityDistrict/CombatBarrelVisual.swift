import SpriteKit

@MainActor
final class CombatBarrelVisual: SKNode {
    init(barrel: CombatBarrel) {
        super.init()
        apply(barrel)
    }
    func apply(_ barrel: CombatBarrel) {
        removeAllChildren()
        name = barrel.exploded ? barrel.id + ".remains" : barrel.id
        position = barrel.position; zPosition = -position.y
        if barrel.isBroken {
            let oil = SKShapeNode(ellipseOf: CGSize(width: 75, height: 43))
            oil.fillColor = SKColor(white: barrel.exploded ? 0.08 : 0.13, alpha: 0.8)
            oil.strokeColor = .clear; oil.position.y = 1; addChild(oil)
        }
        let sprite = SKSpriteNode(imageNamed: barrel.isBroken ? "oil_barrel_debris_v01" : "oil_barrel_v01")
        sprite.size = barrel.isBroken ? CGSize(width: 100, height: 67) : CGSize(width: 60, height: 72)
        sprite.anchorPoint = CGPoint(x: 0.5, y: barrel.isBroken ? 0.5 : 0.13)
        if barrel.exploded { sprite.color = SKColor(white: 0.2, alpha: 1); sprite.colorBlendFactor = 0.45 }
        addChild(sprite)
        if !barrel.exploded {
            let label = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
            label.text = barrel.isBroken ? "Oil spill · flammable" : "Oil · flammable"
            label.fontSize = 10; label.fontColor = .orange
            label.position.y = barrel.isBroken ? 28 : 67; addChild(label)
        }
    }
    required init?(coder: NSCoder) { fatalError("CombatBarrelVisual is created programmatically") }
}

@MainActor
final class BarrelBlastVisual: SKNode {
    private(set) var elapsed: TimeInterval = 0
    var finished: Bool { elapsed >= 0.7 }
    private var particles: [SKSpriteNode] = []
    private let flash = SKSpriteNode(texture: BowArrowFire.softTexture)
    private let ring = SKShapeNode(ellipseOf: CGSize(width: 240, height: 180))
    init(at point: CGPoint) {
        super.init()
        name = "combat.barrel.blast"; position = point; zPosition = 20002
        ring.strokeColor = .orange; ring.lineWidth = 3; addChild(ring)
        flash.blendMode = .add; flash.colorBlendFactor = 1
        flash.color = SKColor(red: 1, green: 0.48, blue: 0.06, alpha: 1)
        flash.position.y = 25; flash.size = CGSize(width: 110, height: 100)
        addChild(flash)
        for i in 0..<36 {
            let particle = SKSpriteNode(texture: BowArrowFire.softTexture)
            particle.colorBlendFactor = 1
            particle.blendMode = i < 24 ? .add : .alpha
            addChild(particle); particles.append(particle)
        }
        advance(delta: 0)
    }
    required init?(coder: NSCoder) { fatalError("BarrelBlastVisual is created programmatically") }
    func advance(delta: TimeInterval) {
        elapsed += delta
        let t = CGFloat(min(1, elapsed / 0.7))
        ring.setScale(0.1 + 0.9 * t); ring.alpha = 0.7 * (1 - t)
        flash.alpha = CGFloat(max(0, 1 - elapsed / 0.24))
        for (i, p) in particles.enumerated() {
            let angle = CGFloat(i) * 2.399963
            let speed = CGFloat(35 + (i * 29) % 86)
            let smoke = i >= 24
            p.position = CGPoint(x: cos(angle) * speed * t,
                                 y: sin(angle) * speed * t * 0.75 + 22 + t * (smoke ? 50 : 20))
            let size = (smoke ? 38.0 : 30.0) * (0.4 + t)
            p.size = CGSize(width: size, height: size * 1.2)
            p.alpha = (1 - t) * (smoke ? 0.7 * t : 1)
            p.color = smoke ? SKColor(white: 0.12, alpha: 1)
                : SKColor(red: 1, green: max(0.15, 0.9 - t), blue: 0.03, alpha: 1)
        }
    }
}
