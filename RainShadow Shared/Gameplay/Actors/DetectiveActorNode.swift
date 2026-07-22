import SpriteKit

@MainActor
final class DetectiveActorNode: SKNode {
    enum State {
        case seatedIdle
        case standingUp
        case standingIdle
        case walking
    }

    private let contactShadow: SKShapeNode
    private let body: SKSpriteNode
    private let foregroundArms: SKSpriteNode
    private let standingTexture: SKTexture?
    private let standingIdleTextures: [ActorFacing: SKTexture]
    private let seatedIdleTextures: [SKTexture]
    private let seatedArmTextures: [SKTexture]
    private let standUpTextures: [SKTexture]
    private let walkTextures: [ActorFacing: [SKTexture]]
    private var facing: ActorFacing = .southEast
    private(set) var state: State = .seatedIdle
    private var pendingWalk: (path: [CGPoint], completion: (() -> Void)?)?
    private var needsSeatEgress = true
    private var routeFollower = RouteFollower()
    private var movementCompletion: (() -> Void)?
    private var lastLocomotionUpdateTime: TimeInterval?
    private var walkFrameAccumulator: TimeInterval = 0
    private var walkFrameIndex = 0

    override init() {
        standingTexture = GameArt.texture(named: "det_standing_idle_se_00")
        standingIdleTextures = Dictionary(uniqueKeysWithValues: ActorFacing.allCases.compactMap { facing -> (ActorFacing, SKTexture)? in
            for sourceName in facing.textureSourceCandidates {
                if let texture = GameArt.texture(
                    named: String(format: "det_standing_idle_%@_00", sourceName)
                ) {
                    return (facing, texture)
                }
            }
            return nil
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
        walkTextures = Dictionary(uniqueKeysWithValues: ActorFacing.allCases.compactMap { facing -> (ActorFacing, [SKTexture])? in
            for sourceName in facing.textureSourceCandidates {
                let textures = (0..<4).compactMap {
                    GameArt.texture(named: String(format: "det_walk_%@_%02d", sourceName, $0))
                }
                if textures.count == 4 {
                    return (facing, textures)
                }
            }
            return nil
        })

        // V5 walk and V4 state atlases carry a 2x copy of a 100px native raster. Nearest filtering
        // resolves it back to the intended lightly pixelated gameplay scale.
        contactShadow = SKShapeNode(ellipseOf: CGSize(width: 54, height: 20))
        contactShadow.fillColor = SKColor(white: 0, alpha: 0.38)
        contactShadow.strokeColor = .clear
        contactShadow.position = CGPoint(x: 0, y: 4)
        contactShadow.setScale(OfficeInteriorScale.ActorDisplay.standingScale)

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
                guard let self else { return }
                guard let pendingWalk = self.pendingWalk else {
                    self.startStandingIdle()
                    return
                }
                self.pendingWalk = nil
                self.beginWalking(path: pendingWalk.path, completion: pendingWalk.completion)
            }
            return
        }

        beginWalking(path: path, completion: completion)
    }

    var movementDestination: CGPoint? {
        pendingWalk?.path.last ?? routeFollower.destination
    }

    /// Advances root motion and the walk cycle from the scene clock. Calling
    /// this while the world is paused intentionally refreshes the timestamp but
    /// spends no movement delta, so opening a modal cannot cause a resume jump.
    func updateLocomotion(at currentTime: TimeInterval, worldIsPaused: Bool) {
        defer { lastLocomotionUpdateTime = currentTime }
        guard !worldIsPaused,
              state == .walking,
              let previousTime = lastLocomotionUpdateTime else {
            return
        }

        let deltaTime = min(
            max(0, currentTime - previousTime),
            ActorLocomotionPacing.maximumFrameDelta
        )
        guard deltaTime > 0 else { return }

        let step = routeFollower.advance(
            from: position,
            deltaTime: deltaTime,
            speed: ActorLocomotionPacing.walkSpeed
        )
        position = step.position
        if step.direction != .zero {
            setFacing(dx: step.direction.dx, dy: step.direction.dy)
            advanceWalkAnimation(by: deltaTime)
        }
        if step.didArrive {
            finishWalking()
        }
    }

    /// BG-style Stop/right-click behavior. A cancelled approach never invokes
    /// its interaction or scene-transition completion.
    func cancelMovement() {
        pendingWalk = nil
        routeFollower.cancel()
        movementCompletion = nil

        switch state {
        case .seatedIdle, .standingIdle:
            return
        case .standingUp, .walking:
            break
        }

        body.removeAction(forKey: "standTransition")
        body.removeAction(forKey: "seatEgress")
        foregroundArms.removeAction(forKey: "standTransition")
        contactShadow.removeAction(forKey: "seatEgress")
        body.position = .zero
        body.alpha = 1
        foregroundArms.isHidden = true
        foregroundArms.alpha = 0
        contactShadow.position.y = 4
        contactShadow.alpha = 0.38
        needsSeatEgress = false
        state = .standingIdle
        stopWalkAnimation()
        startStandingIdle()
    }

    /// The office starts Elias seated at his desk. Outdoor areas instead need a
    /// planted, immediately controllable actor without replaying that office-only
    /// transition or leaving a desk-registered shadow on the pavement.
    func beginOpenWorldStanding() {
        removeAllActions()
        body.removeAllActions()
        foregroundArms.removeAllActions()
        pendingWalk = nil
        routeFollower.cancel()
        movementCompletion = nil
        lastLocomotionUpdateTime = nil
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
        let isCompletingSeatEgress = needsSeatEgress || body.action(forKey: "seatEgress") != nil
        routeFollower.replaceRoute(with: path, from: position)
        movementCompletion = completion
        guard routeFollower.isMoving else {
            if isCompletingSeatEgress {
                // Remain cancellable until the visual root has actually reached
                // the ground point. Stop/right-click must be able to suppress an
                // interaction completion even when no route distance remains.
                needsSeatEgress = false
                state = .walking
                body.removeAction(forKey: "standingIdle")
                animateSeatEgress(duration: 0.42) { [weak self] in
                    guard let self, self.state == .walking else { return }
                    self.finishWalking()
                }
            } else {
                movementCompletion = nil
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

        if let first = routeFollower.waypoints.first {
            setFacing(dx: first.x - position.x, dy: first.y - position.y)
            if isCompletingSeatEgress {
                needsSeatEgress = false
                let firstLegDistance = hypot(first.x - position.x, first.y - position.y)
                animateSeatEgress(
                    duration: ActorLocomotionPacing.pathDuration(distance: firstLegDistance)
                )
            }
        }
    }

    private func finishWalking() {
        routeFollower.cancel()
        stopWalkAnimation()
        state = .standingIdle
        startStandingIdle()
        let completion = movementCompletion
        movementCompletion = nil
        completion?()
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
        applyStandingIdleTexture()
        let settle = SKAction.sequence([
            .moveBy(x: 0, y: 1, duration: 0.7),
            .moveBy(x: 0, y: -1, duration: 0.75)
        ])
        body.run(.repeatForever(settle), withKey: "standingIdle")
    }

    private func setFacing(dx: CGFloat, dy: CGFloat) {
        let nextFacing = ActorFacing.resolve(dx: dx, dy: dy, retaining: facing)
        facing = nextFacing
        applyWalkTexture()
    }

    private func applyWalkTexture() {
        body.xScale = facing.isMirrored
            ? -OfficeInteriorScale.ActorDisplay.standingScale
            : OfficeInteriorScale.ActorDisplay.standingScale
        body.yScale = OfficeInteriorScale.ActorDisplay.standingScale
        body.zRotation = 0
        guard let textures = walkTextures[facing], !textures.isEmpty else { return }
        textures.forEach { $0.filteringMode = .nearest }
        walkFrameIndex %= textures.count
        body.texture = textures[walkFrameIndex]
    }

    private func advanceWalkAnimation(by deltaTime: TimeInterval) {
        guard let textures = walkTextures[facing], !textures.isEmpty else { return }
        walkFrameAccumulator += deltaTime
        while walkFrameAccumulator >= ActorLocomotionPacing.walkCycleSecondsPerFrame {
            walkFrameAccumulator -= ActorLocomotionPacing.walkCycleSecondsPerFrame
            walkFrameIndex = (walkFrameIndex + 1) % textures.count
        }
        applyWalkTexture()
    }

    private func stopWalkAnimation() {
        walkFrameAccumulator = 0
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
