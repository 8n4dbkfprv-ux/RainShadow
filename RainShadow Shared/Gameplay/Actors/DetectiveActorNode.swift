import SpriteKit

@MainActor
final class DetectiveActorNode: SKNode {
    enum State {
        case seatedIdle
        case standingUp
        case standingIdle
        case walking
    }

    private enum Facing: CaseIterable {
        case south
        case southWest
        case west
        case northWest
        case north
        case northEast
        case east
        case southEast

        var sourceName: String {
            switch self {
            case .south: "s"
            case .southWest, .southEast: "sw"
            case .west, .east: "w"
            case .northWest, .northEast: "nw"
            case .north: "n"
            }
        }

        var isMirrored: Bool {
            switch self {
            case .northEast, .east, .southEast: true
            default: false
            }
        }
    }

    private let contactShadow: SKShapeNode
    private let body: SKSpriteNode
    private let foregroundArms: SKSpriteNode
    private let standingTexture: SKTexture?
    private let standingIdleTextures: [Facing: SKTexture]
    private let seatedIdleTextures: [SKTexture]
    private let seatedArmTextures: [SKTexture]
    private let standUpTextures: [SKTexture]
    private let walkTextures: [Facing: [SKTexture]]
    private var facing: Facing = .southEast
    private(set) var state: State = .seatedIdle
    private var pendingWalk: (path: [CGPoint], completion: (() -> Void)?)?
    private var needsSeatEgress = true

    override init() {
        standingTexture = GameArt.texture(named: "det_standing_idle_se_00")
        standingIdleTextures = Dictionary(uniqueKeysWithValues: Facing.allCases.compactMap { facing in
            guard let texture = GameArt.texture(
                named: String(format: "det_standing_idle_%@_00", facing.sourceName)
            ) else { return nil }
            return (facing, texture)
        })
        seatedIdleTextures = (0..<4).compactMap {
            GameArt.texture(named: String(format: "det_seated_idle_se_%02d", $0))
        }
        seatedArmTextures = (0..<4).compactMap {
            GameArt.texture(named: String(format: "det_seated_arms_se_%02d", $0))
        }
        standUpTextures = (0..<12).compactMap {
            GameArt.texture(named: String(format: "det_stand_up_se_%02d", $0))
        }
        walkTextures = Dictionary(uniqueKeysWithValues: Facing.allCases.map { facing in
            let textures = (0..<4).compactMap {
                GameArt.texture(named: String(format: "det_walk_%@_%02d", facing.sourceName, $0))
            }
            return (facing, textures)
        })

        // V4 atlases carry a 2x copy of a 100px native raster. Nearest filtering
        // resolves it back to the intended lightly pixelated gameplay scale.
        contactShadow = SKShapeNode(ellipseOf: CGSize(width: 54, height: 20))
        contactShadow.fillColor = SKColor(white: 0, alpha: 0.38)
        contactShadow.strokeColor = .clear
        contactShadow.position = CGPoint(x: 0, y: 4)

        if let texture = seatedIdleTextures.first ?? standingTexture {
            body = SKSpriteNode(texture: texture, size: CGSize(width: 256, height: 256))
        } else {
            body = SKSpriteNode(color: SKColor(red: 0.12, green: 0.1, blue: 0.1, alpha: 1), size: CGSize(width: 76, height: 142))
        }
        body.anchorPoint = CGPoint(x: 0.5, y: 40 / 256)
        body.texture?.filteringMode = .nearest

        if let texture = seatedArmTextures.first {
            foregroundArms = SKSpriteNode(texture: texture, size: CGSize(width: 256, height: 256))
        } else {
            foregroundArms = SKSpriteNode()
        }
        foregroundArms.anchorPoint = body.anchorPoint
        foregroundArms.texture?.filteringMode = .nearest
        // The desk's front occluder is 86 depth units above the seated actor.
        // This derived arm-only layer clears it without lifting the torso, and
        // also lets the hands naturally overlap loose papers on the desktop.
        foregroundArms.zPosition = 60

        super.init()
        addChild(contactShadow)
        addChild(body)
        addChild(foregroundArms)
        applySeatedPose(animated: false)
        startSeatedIdle()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("DetectiveActorNode is created programmatically")
    }

    func walk(path: [CGPoint], completion: (() -> Void)? = nil) {
        if state == .standingUp {
            pendingWalk = (path, completion)
            return
        }

        if state == .seatedIdle {
            pendingWalk = (path, completion)
            ensureStanding { [weak self] in
                guard let self, let pendingWalk = self.pendingWalk else { return }
                self.pendingWalk = nil
                self.beginWalking(path: pendingWalk.path, completion: pendingWalk.completion)
            }
            return
        }

        beginWalking(path: path, completion: completion)
    }

    /// The office starts Elias seated at his desk. Outdoor areas instead need a
    /// planted, immediately controllable actor without replaying that office-only
    /// transition or leaving a desk-registered shadow on the pavement.
    func beginOpenWorldStanding() {
        removeAllActions()
        body.removeAllActions()
        foregroundArms.removeAllActions()
        pendingWalk = nil
        needsSeatEgress = false
        state = .standingIdle
        body.position = .zero
        body.zRotation = 0
        foregroundArms.isHidden = true
        foregroundArms.alpha = 0
        contactShadow.position = CGPoint(x: 0, y: 4)
        contactShadow.xScale = 1
        contactShadow.yScale = 1
        contactShadow.alpha = 0.38
        startStandingIdle()
    }

    private func beginWalking(path: [CGPoint], completion: (() -> Void)?) {
        removeAction(forKey: "actorPath")
        let isCompletingSeatEgress = needsSeatEgress || body.action(forKey: "seatEgress") != nil
        guard !path.isEmpty else {
            if isCompletingSeatEgress {
                needsSeatEgress = false
                state = .standingIdle
                animateSeatEgress(duration: 0.42) { [weak self] in
                    self?.startStandingIdle()
                    completion?()
                }
            } else {
                state = .standingIdle
                startStandingIdle()
                completion?()
            }
            return
        }

        state = .walking
        body.removeAction(forKey: "standingIdle")
        if !isCompletingSeatEgress {
            body.position.y = 0
        }

        var actions: [SKAction] = []
        var prior = position
        let seatOffset = isCompletingSeatEgress ? body.position : .zero
        for (index, destination) in path.enumerated() {
            // The navigation root is already on the walkable floor in front of the
            // desk, while the seated artwork is registered back at the chair. Make
            // that visual offset part of the first leg so the actor walks out of the
            // chair instead of rising vertically before movement begins.
            let segmentStart = index == 0
                ? CGPoint(x: prior.x + seatOffset.x, y: prior.y + seatOffset.y)
                : prior
            let dx = destination.x - segmentStart.x
            let dy = destination.y - segmentStart.y
            let distance = hypot(dx, dy)
            let duration = ActorLocomotionPacing.pathDuration(distance: distance)
            actions.append(.run { [weak self] in
                guard let self else { return }
                self.setFacing(dx: dx, dy: dy)
                if index == 0, isCompletingSeatEgress {
                    self.needsSeatEgress = false
                    self.animateSeatEgress(duration: duration)
                }
            })
            actions.append(.move(to: destination, duration: duration))
            prior = destination
        }
        actions.append(.run { [weak self] in
            guard let self else { return }
            self.stopWalkAnimation()
            self.state = .standingIdle
            self.startStandingIdle()
            completion?()
        })
        run(.sequence(actions), withKey: "actorPath")
    }

    private func ensureStanding(completion: @escaping () -> Void) {
        guard state == .seatedIdle else {
            completion()
            return
        }
        state = .standingUp
        body.removeAction(forKey: "seatedIdle")
        foregroundArms.removeAction(forKey: "seatedIdle")
        foregroundArms.run(
            .sequence([.fadeOut(withDuration: 0.12), .hide()]),
            withKey: "standTransition"
        )
        let finishStanding = SKAction.run { [weak self] in
            guard let self else { return }
            self.body.texture = self.standingTexture ?? self.walkTextures[.southEast]?.first
            self.body.texture?.filteringMode = .nearest
            self.body.xScale = OfficeInteriorScale.ActorDisplay.standingScale
            self.body.yScale = OfficeInteriorScale.ActorDisplay.standingScale
            self.state = .standingIdle
            completion()
        }
        guard standUpTextures.count == 12 else {
            body.run(
                .sequence([.fadeOut(withDuration: 0.08), finishStanding, .fadeIn(withDuration: 0.12)]),
                withKey: "standTransition"
            )
            return
        }

        standUpTextures.forEach { $0.filteringMode = .nearest }
        let standUp = SKAction.animate(
            with: standUpTextures,
            timePerFrame: ActorLocomotionPacing.standUpSecondsPerFrame,
            resize: false,
            restore: false
        )
        body.run(.sequence([standUp, finishStanding]), withKey: "standTransition")
    }

    private func animateSeatEgress(duration: TimeInterval, completion: (() -> Void)? = nil) {
        body.removeAction(forKey: "seatEgress")
        let settleBody = SKAction.move(to: .zero, duration: duration)
        settleBody.timingMode = .linear
        body.run(
            .sequence([
                settleBody,
                .run { completion?() }
            ]),
            withKey: "seatEgress"
        )

        contactShadow.removeAllActions()
        let settleShadow = SKAction.moveTo(y: 4, duration: duration)
        settleShadow.timingMode = .linear
        contactShadow.run(
            .group([
                settleShadow,
                .sequence([
                    .wait(forDuration: duration * 0.45),
                    .fadeIn(withDuration: duration * 0.55)
                ])
            ]),
            withKey: "seatEgress"
        )
    }

    private func applySeatedPose(animated: Bool) {
        body.texture = seatedIdleTextures.first ?? standingTexture
        body.xScale = OfficeInteriorScale.ActorDisplay.seatedScale
        body.yScale = seatedIdleTextures.isEmpty ? 0.73 : OfficeInteriorScale.ActorDisplay.seatedScale
        body.position.y = OfficeInteriorScale.ActorDisplay.seatedYOffset
        foregroundArms.texture = seatedArmTextures.first
        foregroundArms.xScale = OfficeInteriorScale.ActorDisplay.seatedScale
        foregroundArms.yScale = OfficeInteriorScale.ActorDisplay.seatedScale
        foregroundArms.position.y = OfficeInteriorScale.ActorDisplay.seatedYOffset
        foregroundArms.alpha = seatedArmTextures.isEmpty ? 0 : 1
        foregroundArms.isHidden = seatedArmTextures.isEmpty
        contactShadow.xScale = 0.82
        contactShadow.yScale = 1
        contactShadow.position.y = OfficeInteriorScale.ActorDisplay.seatedYOffset + 4
        // The seated baseline is visually registered behind the desk. A ground
        // contact shadow at that offset projects onto the desktop, so keep it
        // hidden until the first walking leg carries it to the walkable floor root.
        contactShadow.alpha = 0
    }

    private func startSeatedIdle() {
        guard seatedIdleTextures.count > 1 else { return }
        let breathCycle = [0, 1, 2, 3, 2, 1].map { seatedIdleTextures[$0] }
        let animate = SKAction.animate(with: breathCycle, timePerFrame: 0.42, resize: false, restore: false)
        body.run(.repeatForever(animate), withKey: "seatedIdle")

        guard seatedArmTextures.count == seatedIdleTextures.count else { return }
        let armCycle = [0, 1, 2, 3, 2, 1].map { seatedArmTextures[$0] }
        let animateArms = SKAction.animate(
            with: armCycle,
            timePerFrame: 0.42,
            resize: false,
            restore: false
        )
        foregroundArms.run(.repeatForever(animateArms), withKey: "seatedIdle")
    }

    private func startStandingIdle() {
        body.removeAction(forKey: "standingIdle")
        body.removeAction(forKey: "walkCycle")
        applyStandingIdleTexture()
        let settle = SKAction.sequence([
            .moveBy(x: 0, y: 1, duration: 0.7),
            .moveBy(x: 0, y: -1, duration: 0.75)
        ])
        body.run(.repeatForever(settle), withKey: "standingIdle")
    }

    private func setFacing(dx: CGFloat, dy: CGFloat) {
        let angle = atan2(dy, dx)
        let eighthTurn = CGFloat.pi / 8
        let nextFacing: Facing
        switch angle {
        case -eighthTurn..<eighthTurn: nextFacing = .east
        case eighthTurn..<(3 * eighthTurn): nextFacing = .northEast
        case (3 * eighthTurn)..<(5 * eighthTurn): nextFacing = .north
        case (5 * eighthTurn)..<(7 * eighthTurn): nextFacing = .northWest
        case let value where value >= 7 * eighthTurn || value < -7 * eighthTurn: nextFacing = .west
        case (-7 * eighthTurn)..<(-5 * eighthTurn): nextFacing = .southWest
        case (-5 * eighthTurn)..<(-3 * eighthTurn): nextFacing = .south
        default: nextFacing = .southEast
        }

        if facing != nextFacing {
            facing = nextFacing
            startWalkAnimation(for: nextFacing)
        } else if body.action(forKey: "walkCycle") == nil {
            startWalkAnimation(for: nextFacing)
        }
    }

    private func startWalkAnimation(for facing: Facing) {
        body.removeAction(forKey: "walkCycle")
        body.xScale = facing.isMirrored
            ? -OfficeInteriorScale.ActorDisplay.standingScale
            : OfficeInteriorScale.ActorDisplay.standingScale
        body.yScale = OfficeInteriorScale.ActorDisplay.standingScale
        body.zRotation = 0
        guard let textures = walkTextures[facing], textures.count == 4 else {
            let pulse = SKAction.sequence([
                .moveBy(x: 0, y: 2, duration: 0.1),
                .moveBy(x: 0, y: -2, duration: 0.1)
            ])
            body.run(.repeatForever(pulse), withKey: "walkCycle")
            return
        }
        textures.forEach { $0.filteringMode = .nearest }
        let cycle = SKAction.animate(
            with: textures,
            timePerFrame: ActorLocomotionPacing.walkCycleSecondsPerFrame,
            resize: false,
            restore: false
        )
        body.run(.repeatForever(cycle), withKey: "walkCycle")
    }

    private func stopWalkAnimation() {
        body.removeAction(forKey: "walkCycle")
        applyStandingIdleTexture()
        body.position.y = 0
        body.zRotation = 0
    }

    private func applyStandingIdleTexture() {
        if let idleTexture = standingIdleTextures[facing] ?? standingTexture {
            body.texture = idleTexture
            body.texture?.filteringMode = .nearest
        }
        body.xScale = facing.isMirrored
            ? -OfficeInteriorScale.ActorDisplay.standingScale
            : OfficeInteriorScale.ActorDisplay.standingScale
        body.yScale = OfficeInteriorScale.ActorDisplay.standingScale
    }
}
