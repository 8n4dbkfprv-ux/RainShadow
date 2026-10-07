import SpriteKit

/// One accepted shot, sampled by the combat clock. It owns the release and
/// impact markers; neither SKAction timers nor wall time can bypass pause.
@MainActor
final class BowShotPresentation {
    let destructions: [String: BarrelDestruction]
    let displacements: [TacticalCombat.Displacement]
    let explosions: [TacticalCombat.BarrelExplosion]
    let before: TacticalCombat
    let result: TacticalCombat.Strike
    let target: Combatant
    let actor: CharacterAppearanceNode
    let facing: ActorFacing
    let arrow = SKSpriteNode(texture: BowShotPresentation.arrowTexture)
    let fire = BowArrowFire()
    let origin: CGPoint
    let destination: CGPoint
    let impactTime: TimeInterval
    private(set) var elapsed: TimeInterval = 0
    var impactPresented = false
    var finished: Bool { elapsed >= max(BowAttackRules.recoveryTime, impactTime + 0.15) }

    init(before: TacticalCombat, result: TacticalCombat.Strike, target: Combatant,
         actor: CharacterAppearanceNode, parent: SKNode, targetHeight: CGFloat,
         explosions: [TacticalCombat.BarrelExplosion] = [], displacements: [TacticalCombat.Displacement] = [], destructions: [String: BarrelDestruction] = [:]) {
        self.destructions = destructions
        self.explosions = explosions; self.displacements = displacements
        self.before = before; self.result = result; self.target = target; self.actor = actor
        facing = .orient(from: actor.position, to: target.position)
        let offset = BowAttackAnimationSet.muzzleOffset(facing: facing)
        origin = CGPoint(x: actor.position.x + offset.x,
                         y: actor.position.y + offset.y + actor.visualHeightOffset)
        destination = CGPoint(x: target.position.x + (result.damage == 0 ? 22 : 0),
                              y: target.position.y + targetHeight)
        impactTime = BowAttackRules.releaseTime + BowAttackRules.flightDuration(from: actor.position, to: target.position)
        arrow.name = "combat.bow.arrow"
        arrow.size = CGSize(width: 40, height: 7)
        arrow.anchorPoint = CGPoint(x: 1, y: 0.5)
        arrow.zPosition = 20000
        arrow.isHidden = true
        parent.addChild(arrow)
        parent.addChild(fire)
        try? actor.present(action: .shoot, facing: facing, phase: 0)
    }
    func advance(delta: TimeInterval) {
        elapsed += delta
        let phase = min(BowAttackRules.frames - 1, Int(elapsed * BowAttackRules.framesPerSecond))
        try? actor.present(action: .shoot, facing: facing, phase: phase)
        arrow.isHidden = elapsed < BowAttackRules.releaseTime || elapsed >= impactTime
        let progress = (elapsed - BowAttackRules.releaseTime) / (impactTime - BowAttackRules.releaseTime)
        arrow.position = BowAttackRules.arrowPosition(from: origin, to: destination, progress: progress)
        let next = BowAttackRules.arrowPosition(from: origin, to: destination, progress: min(1, progress + 0.01))
        arrow.zRotation = atan2(next.y - arrow.position.y, next.x - arrow.position.x)
        fire.sample(time: elapsed, release: BowAttackRules.releaseTime, impact: impactTime,
                    origin: origin, destination: destination)
    }
    func stop() {
        arrow.removeFromParent()
        fire.removeFromParent()
        try? actor.present(action: .idle, facing: facing, phase: 0)
    }
    private static let arrowTexture: SKTexture = {
        let ctx = CGContext(data: nil, width: 80, height: 14, bitsPerComponent: 8, bytesPerRow: 320,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.setStrokeColor(CGColor(red: 0.12, green: 0.09, blue: 0.06, alpha: 1)); ctx.setLineWidth(4)
        ctx.move(to: CGPoint(x: 4, y: 7)); ctx.addLine(to: CGPoint(x: 71, y: 7)); ctx.strokePath()
        ctx.setStrokeColor(CGColor(red: 0.72, green: 0.53, blue: 0.28, alpha: 1)); ctx.setLineWidth(2)
        ctx.move(to: CGPoint(x: 4, y: 7)); ctx.addLine(to: CGPoint(x: 71, y: 7)); ctx.strokePath()
        ctx.setFillColor(CGColor(red: 0.83, green: 0.86, blue: 0.79, alpha: 1))
        for points in [[CGPoint(x: 79,y: 7), CGPoint(x: 67,y: 11), CGPoint(x: 69,y: 7), CGPoint(x: 67,y: 3)],
                       [CGPoint(x: 4,y: 7), CGPoint(x: 2,y: 13), CGPoint(x: 16,y: 8)],
                       [CGPoint(x: 4,y: 7), CGPoint(x: 2,y: 1), CGPoint(x: 16,y: 6)]] {
            ctx.beginPath(); ctx.move(to: points[0]); points.dropFirst().forEach { ctx.addLine(to: $0) }
            ctx.closePath(); ctx.fillPath()
        }
        return SKTexture(cgImage: ctx.makeImage()!)
    }()
}

/// Small, deterministic flame particles sampled by the same paused combat clock
/// as the projectile. No emitter or SKAction can continue burning during pause.
@MainActor
final class BowArrowFire: SKNode {
    private let glow = SKSpriteNode(texture: BowArrowFire.softTexture)
    private let core = SKSpriteNode(texture: BowArrowFire.softTexture)
    private var flames: [SKSpriteNode] = []
    private var sparks: [SKSpriteNode] = []

    override init() {
        super.init()
        name = "combat.bow.fire"; zPosition = 20001; isHidden = true
        for node in [glow, core] {
            node.blendMode = .add; node.colorBlendFactor = 1; addChild(node)
        }
        glow.color = SKColor(red: 1, green: 0.23, blue: 0.015, alpha: 1)
        core.color = SKColor(red: 1, green: 0.88, blue: 0.35, alpha: 1)
        for i in 0..<20 {
            let particle = SKSpriteNode(texture: Self.softTexture)
            particle.blendMode = .add; particle.colorBlendFactor = 1
            particle.isHidden = true; addChild(particle)
            if i < 14 { flames.append(particle) } else { sparks.append(particle) }
        }
    }
    required init?(coder: NSCoder) { fatalError("BowArrowFire is created programmatically") }

    func sample(time: TimeInterval, release: TimeInterval, impact: TimeInterval,
                origin: CGPoint, destination: CGPoint) {
        let ignition = release - 2 / BowAttackRules.framesPerSecond
        isHidden = time < ignition
        guard !isHidden else { return }
        func tip(at time: Double) -> CGPoint {
            BowAttackRules.arrowPosition(from: origin, to: destination,
                                         progress: (time - release) / (impact - release))
        }
        let head = tip(at: time)
        let flicker = CGFloat(1 + 0.16 * sin(time * 71) + 0.1 * sin(time * 113))
        glow.isHidden = time >= impact; core.isHidden = glow.isHidden
        glow.position = head; glow.size = CGSize(width: 23 * flicker, height: 26 * flicker)
        glow.alpha = 0.65
        core.position = CGPoint(x: head.x, y: head.y + 2)
        core.size = CGSize(width: 7 * flicker, height: 13 * flicker)
        for (particles, interval, life, ember) in [(flames, 1.0 / 100, 0.14, false),
                                                  (sparks, 1.0 / 35, 0.14, true)] {
            for (i, particle) in particles.enumerated() {
                let birth = ignition + (floor((time - ignition) / interval) - Double(i)) * interval
                let age = time - birth
                particle.isHidden = birth < ignition || birth >= impact || age >= life
                guard !particle.isHidden else { continue }
                let seed = sin(birth * 927.1) * 0.5 + 0.5
                let fraction = CGFloat(age / life)
                let point = tip(at: birth)
                particle.position = CGPoint(x: point.x + (seed - 0.5) * age * (ember ? 65 : 35),
                                            y: point.y + age * (ember ? 80 : 45))
                let size = (ember ? 3.0 : 10.0) * (1 - 0.65 * fraction)
                particle.size = CGSize(width: size, height: size * (ember ? 1 : 1.7))
                particle.alpha = (1 - fraction) * (ember ? 0.9 : 0.65)
                particle.color = SKColor(red: 1, green: 0.65 - 0.5 * fraction,
                                         blue: 0.025, alpha: 1)
            }
        }
    }

    static let softTexture: SKTexture = {
        let context = CGContext(data: nil, width: 32, height: 32, bitsPerComponent: 8,
            bytesPerRow: 128, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        let colors = [CGColor(gray: 1, alpha: 1), CGColor(gray: 1, alpha: 0.55),
                      CGColor(gray: 1, alpha: 0)] as CFArray
        let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors,
                                  locations: [0, 0.3, 1])!
        context.drawRadialGradient(gradient, startCenter: CGPoint(x: 16, y: 16), startRadius: 0,
                                   endCenter: CGPoint(x: 16, y: 16), endRadius: 16, options: [])
        return SKTexture(cgImage: context.makeImage()!)
    }()
}
