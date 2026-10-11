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

/// Small cached flame pool over the certified floor cells. Footprint and lifetime
/// come from combat state; wall-clock time only animates the tongues of flame.
@MainActor final class CombatFireSurfaceVisual: SKNode {
    private var flames: [SKSpriteNode] = []
    private let cells: [CGPoint]
    init(barrel: CombatBarrel, artHeight: CGFloat) {
        cells = barrel.fireCells ?? []
        super.init()
        name = "combat.oil.fire." + barrel.id
        for point in cells {
            let stain = SKSpriteNode(texture: BowArrowFire.softTexture)
            stain.size = CGSize(width: 22, height: 16); stain.colorBlendFactor = 1
            stain.position = point; stain.color = SKColor(red: 0.25, green: 0.09, blue: 0.015, alpha: 1)
            stain.alpha = 0.55; stain.zPosition = SceneLayer.depthWorld.rawValue + DrawQueue.depthOffset(groundY: point.y, artHeight: artHeight) - 0.01
            addChild(stain)
            let flame = SKSpriteNode(texture: BowArrowFire.softTexture)
            flame.colorBlendFactor = 1; flame.blendMode = .add
            flame.anchorPoint = CGPoint(x: 0.5, y: 0)
            flame.zPosition = SceneLayer.depthWorld.rawValue + DrawQueue.depthOffset(groundY: point.y, artHeight: artHeight) + 0.01
            addChild(flame); flames.append(flame)
        }
    }
    required init?(coder: NSCoder) { fatalError("Programmatic fire surface") }
    func sample(time: TimeInterval) {
        for (i, flame) in flames.enumerated() {
            let phase = (time * 1.6 + Double(i) * 0.61803398875).truncatingRemainder(dividingBy: 1)
            let seed = Double(i) * 137.31
            flame.position = CGPoint(x: cells[i].x + sin(seed) * 5 + sin(time * 5 + Double(i)) * 2,
                                     y: cells[i].y - 4 + cos(seed) * 3)
            flame.size = CGSize(width: 14 - 5 * phase,
                                height: 10 + (10 + 9 * abs(sin(seed))) * sin(phase * .pi))
            flame.zRotation = sin(time * 3 + seed) * 0.16
            flame.color = SKColor(red: 1, green: 0.65 - 0.5 * phase, blue: 0.025, alpha: 1)
            flame.alpha = 0.5 + 0.35 * sin(phase * .pi)
        }
    }
}

@MainActor final class CombatWaterSplash: SKNode {
    override init() {
        super.init()
        name = "combat.water.splash"
        for i in 0..<3 {
            let ring = SKShapeNode(ellipseOf: CGSize(width: 34, height: 25.5))
            ring.strokeColor = SKColor(red: 0.67, green: 0.82, blue: 0.83, alpha: 0.75)
            ring.lineWidth = 2; addChild(ring)
            ring.run(.sequence([.wait(forDuration: Double(i) * 0.12),
                .group([.scale(to: 2.8, duration: 0.8), .fadeOut(withDuration: 0.8)])]))
        }
        for i in 0..<10 {
            let drop = SKSpriteNode(texture: BowArrowFire.softTexture)
            drop.colorBlendFactor = 1; drop.color = SKColor(red: 0.73, green: 0.9, blue: 0.9, alpha: 1)
            drop.size = CGSize(width: 4, height: 7); addChild(drop)
            let angle = Double(i) * .pi / 5
            drop.run(.sequence([.moveBy(x: cos(angle) * 24, y: 18 + sin(angle) * 10, duration: 0.2),
                .group([.moveBy(x: cos(angle) * 10, y: -24, duration: 0.3), .fadeOut(withDuration: 0.3)])]))
        }
        run(.sequence([.wait(forDuration: 1.2), .removeFromParent()]))
    }
    required init?(coder: NSCoder) { fatalError("Programmatic water splash") }
}
