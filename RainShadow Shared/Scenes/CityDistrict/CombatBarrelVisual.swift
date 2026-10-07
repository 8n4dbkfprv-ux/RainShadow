import SpriteKit

@MainActor
final class CombatBarrelVisual: SKNode {
    private(set) var destruction: BarrelDestruction?
    private(set) var elapsed: TimeInterval = 0
    private(set) var fragmentBodies: [BarrelFragmentBody] = []
    private var fragmentNodes: [(root: SKNode, sprite: SKSpriteNode, shadow: SKSpriteNode)] = []
    private let shadowAlpha: CGFloat
    var isSimulating: Bool { destruction != nil }
    private static let fragmentTextures: [SKTexture] = {
        let sheet = SKTexture(imageNamed: "oil_barrel_fragments_v01")
        // The generated atlas is retained intact; these are texture views.
        return [(0.0, 0.5), (0.5, 0.5), (0.0, 0.0), (0.5, 0.0)].map {
            let texture = SKTexture(rect: CGRect(x: $0.0, y: $0.1, width: 0.5, height: 0.5), in: sheet)
            texture.filteringMode = .linear
            return texture
        }
    }()
    init(barrel: CombatBarrel, lighting: ActorSceneLighting = .neutral) {
        shadowAlpha = ContactShadowKind.npc.standingAlpha * lighting.contactShadowAlphaScale
        super.init()
        apply(barrel)
    }
    func apply(_ barrel: CombatBarrel, destruction: BarrelDestruction? = nil) {
        removeAllChildren(); fragmentNodes.removeAll(); fragmentBodies.removeAll()
        self.destruction = destruction; elapsed = 0
        name = barrel.exploded ? barrel.id + ".remains" : barrel.id
        position = barrel.position
        // Preserve the scene's registered depth when transitioning into debris.
        if barrel.isBroken {
            // Overlapping soft patches keep the stain irregular when the pieces scatter.
            for (x, y, width, height) in [(0.0, 0.0, 88.0, 53.0), (-15, 4, 43, 28),
                                         (17, -5, 49, 30), (3, 13, 38, 25)] {
                let oil = SKSpriteNode(texture: BowArrowFire.softTexture)
                oil.color = barrel.exploded ? SKColor(white: 0.04, alpha: 1)
                    : SKColor(red: 0.10, green: 0.08, blue: 0.035, alpha: 1)
                oil.colorBlendFactor = 1; oil.alpha = barrel.exploded ? 0.62 : 0.72
                oil.size = CGSize(width: width, height: height)
                oil.position = CGPoint(x: x, y: y); oil.zPosition = -0.01; addChild(oil)
            }
        }
        if let poses = barrel.debris {
            for pose in poses {
                let root = SKNode(); root.name = "combat.barrel.fragment"
                let sprite = SKSpriteNode(texture: Self.fragmentTextures[pose.kind.rawValue])
                let size: CGFloat = switch pose.kind { case .stave: 34; case .splinter: 23; case .lid: 38; case .hoop: 43 }
                sprite.size = CGSize(width: size * pose.scale, height: size * pose.scale)
                if barrel.exploded { sprite.color = SKColor(white: 0.2, alpha: 1); sprite.colorBlendFactor = 0.3 }
                let width: CGFloat = switch pose.kind { case .stave: 19; case .splinter: 11; case .lid: 27; case .hoop: 30 }
                let shadow = makeShadow(size: CGSize(width: width * pose.scale, height: width * pose.scale * 0.5))
                root.addChild(shadow); root.addChild(sprite); addChild(root)
                fragmentNodes.append((root, sprite, shadow))
            }
            let bodies = destruction?.sample(at: 0) ?? poses.map {
                BarrelFragmentBody(pose: $0, height: 0, velocity: .zero, liftSpeed: 0, spin: 0, sleeping: true)
            }
            present(bodies)
        } else {
            // Old saves retain their original pile; new breaks use individual pieces.
            let shadow = makeShadow(size: barrel.isBroken ? CGSize(width: 75, height: 34)
                : CGSize(width: 48, height: 25))
            shadow.position = CGPoint(x: 1, y: 1)
            addChild(shadow)
            let sprite = SKSpriteNode(imageNamed: barrel.isBroken ? "oil_barrel_debris_v01" : "oil_barrel_v01")
            sprite.size = barrel.isBroken ? CGSize(width: 100, height: 67) : CGSize(width: 60, height: 72)
            sprite.anchorPoint = CGPoint(x: 0.5, y: barrel.isBroken ? 0.5 : 0.13)
            if barrel.exploded { sprite.color = SKColor(white: 0.2, alpha: 1); sprite.colorBlendFactor = 0.45 }
            addChild(sprite)
        }
        if !barrel.exploded {
            let label = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
            label.text = barrel.isBroken ? "Oil spill · flammable" : "Oil · flammable"
            label.fontSize = 10; label.fontColor = .orange
            label.position.y = barrel.isBroken ? 28 : 67; label.zPosition = 1; addChild(label)
        }
    }
    func advance(delta: TimeInterval) {
        guard let destruction else { return }
        elapsed = min(destruction.duration, elapsed + max(0, delta))
        present(destruction.sample(at: elapsed))
        if elapsed >= destruction.duration { self.destruction = nil }
    }
    private func present(_ bodies: [BarrelFragmentBody]) {
        fragmentBodies = bodies
        for (body, node) in zip(bodies, fragmentNodes) {
            node.root.position = CGPoint(x: body.pose.point.x - position.x, y: body.pose.point.y - position.y)
            node.root.zPosition = (position.y - body.pose.point.y) * DrawQueue.unitsPerWorldY + 0.002
            node.sprite.position.y = body.height
            node.sprite.zRotation = body.pose.angle
            // A billboard tumble, with ground flattening once the piece rests.
            node.sprite.yScale = body.height > 0 ? 0.45 + 0.55 * abs(cos(body.pose.angle * 0.8)) : 0.75
            node.shadow.alpha = shadowAlpha / (1 + body.height / 40)
            let spread = 1 + min(0.6, body.height / 120)
            node.shadow.xScale = spread * 1.06
            node.shadow.yScale = spread
        }
    }
    private func makeShadow(size: CGSize) -> SKSpriteNode {
        let shadow = ContactShadowFactory.make(kind: .npc, scale: 1)
        shadow.name = "combat.barrel.contact-shadow"
        shadow.size = size
        shadow.position = .zero // Floor contact; fragment height only raises its body.
        shadow.alpha = shadowAlpha
        shadow.zPosition = -0.001
        return shadow
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
