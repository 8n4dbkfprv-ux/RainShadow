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
    let releaseTime: TimeInterval
    let impactTime: TimeInterval
    private(set) var elapsed: TimeInterval = 0
    var impactPresented = false
    var dodgePresented = false
    var isSneakAttack: Bool { StealthAnimationSet.usesAttack(result) }
    var finished: Bool { elapsed >= max(isSneakAttack ? StealthAnimationSet.bowDuration : WeaponTechniqueMotion.bowDuration(result.maneuver), impactTime + (result.fireArrow ? 0.5 : 0.15)) }

    init(before: TacticalCombat, result: TacticalCombat.Strike, target: Combatant,
         actor: CharacterAppearanceNode, parent: SKNode, targetHeight: CGFloat,
         explosions: [TacticalCombat.BarrelExplosion] = [], displacements: [TacticalCombat.Displacement] = [], destructions: [String: BarrelDestruction] = [:]) {
        self.destructions = destructions
        self.explosions = explosions; self.displacements = displacements
        self.before = before; self.result = result; self.target = target; self.actor = actor
        facing = .orient(from: actor.position, to: target.position)
        let offset = StealthAnimationSet.usesAttack(result) ? StealthAnimationSet.muzzleOffset(facing: facing) : result.maneuver == .pinningShot
            ? WeaponTechniqueAnimationSet.pinningMuzzle(facing: facing) : BowAttackAnimationSet.muzzleOffset(facing: facing)
        origin = CGPoint(x: actor.position.x + offset.x,
                         y: actor.position.y + offset.y + actor.visualHeightOffset)
        destination = CGPoint(x: target.position.x + (result.damage == 0 ? 22 : 0),
                              y: target.position.y + (target.isProne ? 15 : result.maneuver == .pinningShot ? 15 : targetHeight))
        releaseTime = StealthAnimationSet.usesAttack(result) ? StealthAnimationSet.bowRelease : WeaponTechniqueMotion.bowRelease(result.maneuver)
        impactTime = releaseTime + BowAttackRules.flightDuration(from: actor.position, to: target.position)
        arrow.name = "combat.bow.arrow"
        arrow.size = CGSize(width: 40, height: 7)
        arrow.anchorPoint = CGPoint(x: 1, y: 0.5)
        arrow.zPosition = 20000
        arrow.isHidden = true
        parent.addChild(arrow)
        if result.fireArrow || !explosions.isEmpty { parent.addChild(fire) }
        present(phase: 0)
    }
    func advance(delta: TimeInterval) {
        elapsed += delta
        let phase = isSneakAttack ? StealthAnimationSet.phase(.sneakshoot, elapsed: elapsed) : WeaponTechniqueMotion.bowPhase(elapsed: elapsed, move: result.maneuver)
        present(phase: phase)
        arrow.isHidden = elapsed < releaseTime || elapsed >= impactTime
        let progress = (elapsed - releaseTime) / (impactTime - releaseTime)
        arrow.position = BowAttackRules.arrowPosition(from: origin, to: destination, progress: progress)
        let next = BowAttackRules.arrowPosition(from: origin, to: destination, progress: min(1, progress + 0.01))
        arrow.zRotation = atan2(next.y - arrow.position.y, next.x - arrow.position.x)
        fire.sample(time: elapsed, release: releaseTime, impact: impactTime,
                    origin: origin, destination: destination, burst: result.fireArrow && result.damage > 0)
    }
    private func present(phase: Int) {
        if isSneakAttack { try? actor.presentStealth(.sneakshoot, facing: facing, phase: phase) }
        else { try? actor.presentTechnique(result.maneuver, action: .shoot, facing: facing, phase: phase) }
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
    private var impactFlames: [SKSpriteNode] = []

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
        for _ in 0..<18 {
            let node = SKSpriteNode(texture: Self.softTexture)
            node.colorBlendFactor = 1; node.blendMode = .add; node.isHidden = true
            addChild(node); impactFlames.append(node)
        }
    }
    required init?(coder: NSCoder) { fatalError("BowArrowFire is created programmatically") }

    func sample(time: TimeInterval, release: TimeInterval, impact: TimeInterval,
                origin: CGPoint, destination: CGPoint, burst: Bool = false) {
        let sinceImpact = time - impact
        for (i, node) in impactFlames.enumerated() {
            node.isHidden = !burst || sinceImpact < 0 || sinceImpact >= 0.45
            guard !node.isHidden else { continue }
            let phase = sinceImpact / 0.45
            let angle = Double(i) * 2.399963
            let radius = (8 + Double(i % 4) * 4) * phase
            node.position = CGPoint(x: destination.x + cos(angle) * radius,
                y: destination.y + sin(angle) * radius * 0.7 + phase * 12)
            let size = (11 - 6 * phase)
            node.size = CGSize(width: size, height: size * 1.6)
            node.alpha = 0.8 * (1 - phase)
            node.color = SKColor(red: 1, green: 0.8 - phase * 0.65, blue: 0.03, alpha: 1)
        }
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

/// A bounded particle pool, attached to the currently visible actor/proxy. All
/// motion is sampled from the director's combat clock, including smoke and glow.
@MainActor
final class CharacterBurningVisual: SKNode {
    private let glow = SKSpriteNode(texture: BowArrowFire.softTexture)
    private var flames: [SKSpriteNode] = []
    private var smoke: [SKSpriteNode] = []
    private var embers: [SKSpriteNode] = []
    override init() {
        super.init()
        name = "combat.character.burning"; zPosition = 0.5
        glow.colorBlendFactor = 1; glow.color = SKColor(red: 1, green: 0.22, blue: 0.015, alpha: 1)
        glow.blendMode = .add; addChild(glow)
        for i in 0..<40 {
            let node = SKSpriteNode(texture: BowArrowFire.softTexture)
            node.colorBlendFactor = 1
            if i < 10 {
                node.blendMode = .alpha
                node.color = SKColor(white: 0.16, alpha: 1)
                smoke.append(node)
            } else {
                node.blendMode = .add
                if i < 34 { flames.append(node) } else { embers.append(node) }
            }
            addChild(node)
        }
    }
    required init?(coder: NSCoder) { fatalError("CharacterBurningVisual is created programmatically") }
    func sample(time: TimeInterval, bear: Bool) {
        let width = bear ? 28.0 : 14.0
        let base = bear ? 18.0 : 24.0
        glow.position = CGPoint(x: 0, y: base + 9)
        glow.size = CGSize(width: width * 3, height: 50)
        glow.alpha = 0.19 + 0.045 * sin(time * 23)
        for (pool, life, kind) in [(smoke, 1.5, 0), (flames, 0.64, 1), (embers, 0.95, 2)] {
            for (i, node) in pool.enumerated() {
                let offset = Double(i) * 0.61803398875
                let phase = (time / life + offset).truncatingRemainder(dividingBy: 1)
                let seed = sin(Double(i) * 137.31)
                let drift = sin(time * 6 + Double(i) * 3) * (kind == 0 ? 5 : 2)
                node.position = CGPoint(x: seed * width + drift + phase * seed * (kind == 0 ? 9 : 3),
                    y: base + Double(i % 3) * 7 + phase * (kind == 0 ? 56 : kind == 1 ? 23 : 50))
                let size = kind == 0 ? 13 + 16 * phase : kind == 1 ? 9 * (1 - 0.65 * phase) : 1.8
                node.size = CGSize(width: size, height: size * (kind == 1 ? 2.3 : 1))
                node.alpha = sin(phase * .pi) * (kind == 0 ? 0.24 : kind == 1 ? 0.78 : 0.9)
                if kind != 0 {
                    node.color = SKColor(red: 1, green: 0.72 - 0.6 * phase, blue: 0.025, alpha: 1)
                }
            }
        }
    }
}
