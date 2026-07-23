import SpriteKit

@MainActor
final class DetectiveActorNode: SKNode {
    enum State {
        case seatedIdle
        case standingUp
        case sittingDown
        case standingIdle
        case walking
    }

    private let contactShadow: SKShapeNode
    /// Standing / transitions / seated upper (torso, fedora, arms).
    private let body: SKSpriteNode
    /// Seated lower only (chair legs + coat tails); hidden while standing.
    private let lowerBody: SKSpriteNode
    private let foregroundArms: SKSpriteNode
    private let standingTexture: SKTexture?
    private let standingIdleTextures: [ActorFacing: [SKTexture]]
    private let seatedIdleTextures: [SKTexture]
    private let seatedUpperTextures: [SKTexture]
    private let seatedLowerTextures: [SKTexture]
    private let seatedArmTextures: [SKTexture]
    private let standUpTextures: [SKTexture]
    private let sitDownTextures: [SKTexture]
    private let walkTextures: [ActorFacing: [SKTexture]]

    /// Local z so the desk apron occluder can sit between lower and upper while seated.
    private static let seatedUpperLocalZ: CGFloat = 70
    private static let seatedLowerLocalZ: CGFloat = 0
    private var facing: ActorFacing = .northEast
    private(set) var state: State = .seatedIdle
    private var pendingWalk: (path: [CGPoint], completion: (() -> Void)?)?
    private var needsSeatEgress = true
    private var routeFollower = RouteFollower()
    private var movementCompletion: (() -> Void)?
    private var lastLocomotionUpdateTime: TimeInterval?
    private var walkFrameAccumulator: TimeInterval = 0
    private var walkFrameIndex = 0

    /// True while the body is still registered to the chair (idle or sitting down).
    /// Used by the office scene to cancel the elevated nav-root in Y-depth sorting.
    var isSeated: Bool {
        switch state {
        case .seatedIdle, .sittingDown:
            return true
        case .standingUp, .standingIdle, .walking:
            return false
        }
    }

    override init() {
        standingTexture = GameArt.texture(named: "voss_standing_idle_se_00")
        standingIdleTextures = Dictionary(uniqueKeysWithValues: ActorFacing.allCases.compactMap { facing -> (ActorFacing, [SKTexture])? in
            for sourceName in facing.textureSourceCandidates {
                let textures = (0..<4).compactMap {
                    GameArt.texture(named: String(format: "voss_standing_idle_%@_%02d", sourceName, $0))
                }
                if !textures.isEmpty {
                    return (facing, textures)
                }
            }
            return nil
        })
        // Desk faces the NE door: seated work pose looks toward the visitor/door.
        seatedIdleTextures = (0..<8).compactMap {
            GameArt.texture(named: String(format: "voss_seated_idle_ne_%02d", $0))
                ?? GameArt.texture(named: String(format: "voss_seated_idle_se_%02d", $0))
        }
        seatedUpperTextures = (0..<8).compactMap {
            GameArt.texture(named: String(format: "voss_seated_upper_ne_%02d", $0))
        }
        seatedLowerTextures = (0..<8).compactMap {
            GameArt.texture(named: String(format: "voss_seated_lower_ne_%02d", $0))
        }
        seatedArmTextures = (0..<8).compactMap {
            GameArt.texture(named: String(format: "voss_seated_arms_ne_%02d", $0))
                ?? GameArt.texture(named: String(format: "voss_seated_arms_se_%02d", $0))
        }
        standUpTextures = (0..<12).compactMap {
            GameArt.texture(named: String(format: "voss_stand_up_ne_%02d", $0))
                ?? GameArt.texture(named: String(format: "voss_stand_up_se_%02d", $0))
        }
        sitDownTextures = (0..<12).compactMap {
            GameArt.texture(named: String(format: "voss_sit_down_ne_%02d", $0))
                ?? GameArt.texture(named: String(format: "voss_sit_down_se_%02d", $0))
        }
        walkTextures = Dictionary(uniqueKeysWithValues: ActorFacing.allCases.compactMap { facing -> (ActorFacing, [SKTexture])? in
            for sourceName in facing.textureSourceCandidates {
                let textures = (0..<ActorLocomotionPacing.walkFramesPerCycle).compactMap {
                    GameArt.texture(named: String(format: "voss_walk_%@_%02d", sourceName, $0))
                }
                if textures.count == ActorLocomotionPacing.walkFramesPerCycle {
                    return (facing, textures)
                }
            }
            return nil
        })

        // V7 atlases carry a 200px nearest-upscaled copy of an 80px native raster.
        // Nearest filtering resolves it back to the intended pixelated BGEE gameplay scale.
        contactShadow = SKShapeNode(ellipseOf: CGSize(width: 54, height: 20))
        contactShadow.fillColor = SKColor(white: 0, alpha: 0.38)
        contactShadow.strokeColor = .clear
        contactShadow.position = CGPoint(x: 0, y: 4)
        contactShadow.setScale(OfficeInteriorScale.ActorDisplay.standingScale)

        let initialSeated = seatedUpperTextures.first ?? seatedIdleTextures.first ?? standingTexture
        if let texture = initialSeated {
            body = SKSpriteNode(texture: texture, size: CGSize(width: 256, height: 256))
        } else {
            body = SKSpriteNode(color: SKColor(red: 0.12, green: 0.1, blue: 0.1, alpha: 1), size: CGSize(width: 76, height: 142))
        }
        body.anchorPoint = CGPoint(x: 0.5, y: 40 / 256)
        body.texture?.filteringMode = .nearest

        if let texture = seatedLowerTextures.first {
            lowerBody = SKSpriteNode(texture: texture, size: CGSize(width: 256, height: 256))
        } else {
            lowerBody = SKSpriteNode()
        }
        lowerBody.anchorPoint = body.anchorPoint
        lowerBody.texture?.filteringMode = .nearest
        lowerBody.zPosition = Self.seatedLowerLocalZ

        if let texture = seatedArmTextures.first {
            foregroundArms = SKSpriteNode(texture: texture, size: CGSize(width: 256, height: 256))
        } else {
            foregroundArms = SKSpriteNode()
        }
        foregroundArms.anchorPoint = body.anchorPoint
        foregroundArms.texture?.filteringMode = .nearest
        // Upper body clears the kneehole apron; arms stay above that for desk papers.
        foregroundArms.zPosition = Self.seatedUpperLocalZ + 15

        super.init()
        addChild(contactShadow)
        addChild(lowerBody)
        addChild(body)
        addChild(foregroundArms)
        applySeatedPose(animated: false)
        startSeatedIdle()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("DetectiveActorNode is created programmatically")
    }

    func walk(path: [CGPoint], completion: (() -> Void)? = nil) {
        if state == .standingUp || state == .sittingDown {
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
        case .seatedIdle, .standingIdle, .sittingDown:
            return
        case .standingUp, .walking:
            break
        }

        body.removeAction(forKey: "standTransition")
        body.removeAction(forKey: "seatEgress")
        lowerBody.removeAction(forKey: "standTransition")
        lowerBody.removeAction(forKey: "seatEgress")
        foregroundArms.removeAction(forKey: "standTransition")
        contactShadow.removeAction(forKey: "seatEgress")
        body.position = .zero
        body.zPosition = 0
        body.alpha = 1
        hideLowerBody()
        foregroundArms.isHidden = true
        foregroundArms.alpha = 0
        contactShadow.position.y = 4
        contactShadow.alpha = 0.38
        needsSeatEgress = false
        state = .standingIdle
        stopWalkAnimation()
        startStandingIdle()
    }

    /// The office starts Voss seated at his desk. Outdoor areas instead need a
    /// planted, immediately controllable actor without replaying that office-only
    /// transition or leaving a desk-registered shadow on the pavement.
    func beginOpenWorldStanding() {
        removeAllActions()
        body.removeAllActions()
        lowerBody.removeAllActions()
        foregroundArms.removeAllActions()
        pendingWalk = nil
        routeFollower.cancel()
        movementCompletion = nil
        lastLocomotionUpdateTime = nil
        needsSeatEgress = false
        state = .standingIdle
        body.position = .zero
        body.zPosition = 0
        body.zRotation = 0
        hideLowerBody()
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
            lowerBody.position = .zero
            body.zPosition = 0
            hideLowerBody()
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
        lowerBody.removeAction(forKey: "seatedIdle")
        foregroundArms.removeAction(forKey: "seatedIdle")
        // Collapse to a single full-body layer for the stand-up strip.
        body.texture = seatedIdleTextures.first ?? body.texture
        body.zPosition = 0
        hideLowerBody()
        foregroundArms.run(
            .sequence([.fadeOut(withDuration: 0.12), .hide()]),
            withKey: "standTransition"
        )
        let finishStanding = SKAction.run { [weak self] in
            guard let self else { return }
            self.body.texture = self.standingTexture ?? self.walkTextures[.northEast]?.first
            self.body.texture?.filteringMode = .nearest
            self.body.xScale = OfficeInteriorScale.ActorDisplay.standingScale
            self.body.yScale = OfficeInteriorScale.ActorDisplay.standingScale
            self.body.zPosition = 0
            self.hideLowerBody()
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

    /// Plays the authored V6 sit-down clip (not a reversed stand-up) and
    /// re-enters the seated desk idle. A walk order issued mid-sit queues and
    /// replays the stand-up chain once the actor has settled.
    func sitDown(completion: (() -> Void)? = nil) {
        guard state == .standingIdle else {
            completion?()
            return
        }
        state = .sittingDown
        body.removeAction(forKey: "standingIdle")
        facing = .northEast
        body.zPosition = 0
        hideLowerBody()

        let finishSitting = SKAction.run { [weak self] in
            guard let self else { return }
            self.applySeatedPose(animated: false)
            self.startSeatedIdle()
            self.needsSeatEgress = true
            self.state = .seatedIdle
            if let pendingWalk = self.pendingWalk {
                self.pendingWalk = nil
                self.walk(path: pendingWalk.path, completion: pendingWalk.completion)
            } else {
                completion?()
            }
        }

        guard sitDownTextures.count == 12 else {
            body.run(
                .sequence([.fadeOut(withDuration: 0.08), finishSitting, .fadeIn(withDuration: 0.12)]),
                withKey: "standTransition"
            )
            return
        }

        sitDownTextures.forEach { $0.filteringMode = .nearest }
        let duration = ActorLocomotionPacing.standUpSecondsPerFrame * TimeInterval(sitDownTextures.count)
        let sitDown = SKAction.animate(
            with: sitDownTextures,
            timePerFrame: ActorLocomotionPacing.standUpSecondsPerFrame,
            resize: false,
            restore: false
        )
        let nudge = OfficeInteriorScale.ActorDisplay.seatedDeskNudge
        let seat = CGPoint(
            x: nudge.x,
            y: OfficeInteriorScale.ActorDisplay.seatedYOffset + nudge.y
        )
        let settle = SKAction.move(to: seat, duration: duration)
        settle.timingMode = .linear
        body.xScale = OfficeInteriorScale.ActorDisplay.standingScale
        body.yScale = OfficeInteriorScale.ActorDisplay.standingScale
        contactShadow.run(.fadeOut(withDuration: duration * 0.5))
        body.run(.sequence([.group([sitDown, settle]), finishSitting]), withKey: "standTransition")
    }

    private func animateSeatEgress(duration: TimeInterval, completion: (() -> Void)? = nil) {
        body.removeAction(forKey: "seatEgress")
        lowerBody.removeAction(forKey: "seatEgress")
        let settleBody = SKAction.move(to: .zero, duration: duration)
        settleBody.timingMode = .linear
        body.run(
            .sequence([
                settleBody,
                .run { completion?() }
            ]),
            withKey: "seatEgress"
        )
        lowerBody.run(settleBody, withKey: "seatEgress")

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

    private func hideLowerBody() {
        lowerBody.removeAllActions()
        lowerBody.isHidden = true
        lowerBody.alpha = 0
        lowerBody.zPosition = Self.seatedLowerLocalZ
    }

    private func applySeatedPose(animated: Bool) {
        let nudge = OfficeInteriorScale.ActorDisplay.seatedDeskNudge
        let seat = CGPoint(
            x: nudge.x,
            y: OfficeInteriorScale.ActorDisplay.seatedYOffset + nudge.y
        )
        let useSplit = !seatedUpperTextures.isEmpty && !seatedLowerTextures.isEmpty
        if useSplit {
            body.texture = seatedUpperTextures.first
            body.zPosition = Self.seatedUpperLocalZ
            lowerBody.texture = seatedLowerTextures.first
            lowerBody.texture?.filteringMode = .nearest
            lowerBody.xScale = OfficeInteriorScale.ActorDisplay.seatedScale
            lowerBody.yScale = OfficeInteriorScale.ActorDisplay.seatedScale
            lowerBody.position = seat
            lowerBody.zPosition = Self.seatedLowerLocalZ
            lowerBody.alpha = 1
            lowerBody.isHidden = false
        } else {
            body.texture = seatedIdleTextures.first ?? standingTexture
            body.zPosition = 0
            hideLowerBody()
        }
        body.texture?.filteringMode = .nearest
        body.xScale = OfficeInteriorScale.ActorDisplay.seatedScale
        body.yScale = (useSplit || !seatedIdleTextures.isEmpty)
            ? OfficeInteriorScale.ActorDisplay.seatedScale
            : 0.73
        body.position = seat
        // Upper already carries hands for the NE rear view; keep arms overlay empty.
        foregroundArms.texture = seatedArmTextures.first
        foregroundArms.xScale = OfficeInteriorScale.ActorDisplay.seatedScale
        foregroundArms.yScale = OfficeInteriorScale.ActorDisplay.seatedScale
        foregroundArms.position = seat
        foregroundArms.zPosition = Self.seatedUpperLocalZ + 15
        let armsVisible = !useSplit && !seatedArmTextures.isEmpty
        foregroundArms.alpha = armsVisible ? 1 : 0
        foregroundArms.isHidden = !armsVisible
        contactShadow.xScale = 0.82
        contactShadow.yScale = 1
        contactShadow.position = CGPoint(x: seat.x, y: seat.y + 4)
        // The seated baseline is visually registered behind the desk. A ground
        // contact shadow at that offset projects onto the desktop, so keep it
        // hidden until the first walking leg carries it to the walkable floor root.
        contactShadow.alpha = 0
    }

    /// Ping-pong breath indices for an authored strip (e.g. 8 frames -> 0...7...1).
    private static func breathCycleIndices(frameCount: Int) -> [Int] {
        guard frameCount > 1 else { return Array(0..<max(1, frameCount)) }
        return Array(0..<frameCount) + Array((1..<(frameCount - 1)).reversed())
    }

    private func startSeatedIdle() {
        let useSplit = seatedUpperTextures.count > 1 && seatedLowerTextures.count == seatedUpperTextures.count
        if useSplit {
            let indices = Self.breathCycleIndices(frameCount: seatedUpperTextures.count)
            let upperCycle = indices.map { seatedUpperTextures[$0] }
            let lowerCycle = indices.map { seatedLowerTextures[$0] }
            let animateUpper = SKAction.animate(with: upperCycle, timePerFrame: 0.21, resize: false, restore: false)
            let animateLower = SKAction.animate(with: lowerCycle, timePerFrame: 0.21, resize: false, restore: false)
            body.run(.repeatForever(animateUpper), withKey: "seatedIdle")
            lowerBody.run(.repeatForever(animateLower), withKey: "seatedIdle")
            return
        }

        guard seatedIdleTextures.count > 1 else { return }
        let indices = Self.breathCycleIndices(frameCount: seatedIdleTextures.count)
        let breathCycle = indices.map { seatedIdleTextures[$0] }
        let animate = SKAction.animate(with: breathCycle, timePerFrame: 0.21, resize: false, restore: false)
        body.run(.repeatForever(animate), withKey: "seatedIdle")

        guard seatedArmTextures.count == seatedIdleTextures.count else { return }
        let armCycle = indices.map { seatedArmTextures[$0] }
        let animateArms = SKAction.animate(
            with: armCycle,
            timePerFrame: 0.21,
            resize: false,
            restore: false
        )
        foregroundArms.run(.repeatForever(animateArms), withKey: "seatedIdle")
    }

    private func startStandingIdle() {
        body.removeAction(forKey: "standingIdle")
        applyStandingIdleTexture()
        if let frames = standingIdleTextures[facing], frames.count > 1 {
            // Authored 4-frame breath loop with a long neutral hold, replacing
            // the former single-frame position bob.
            frames.forEach { $0.filteringMode = .nearest }
            let indices = Self.breathCycleIndices(frameCount: frames.count)
            let breath = SKAction.animate(
                with: indices.map { frames[$0] },
                timePerFrame: 0.42,
                resize: false,
                restore: false
            )
            let hold = SKAction.wait(forDuration: 0.9)
            body.run(.repeatForever(.sequence([breath, hold])), withKey: "standingIdle")
        } else {
            let settle = SKAction.sequence([
                .moveBy(x: 0, y: 1, duration: 0.7),
                .moveBy(x: 0, y: -1, duration: 0.75)
            ])
            body.run(.repeatForever(settle), withKey: "standingIdle")
        }
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
        if let idleTexture = standingIdleTextures[facing]?.first ?? standingTexture {
            body.texture = idleTexture
            body.texture?.filteringMode = .nearest
        }
        body.xScale = facing.isMirrored
            ? -OfficeInteriorScale.ActorDisplay.standingScale
            : OfficeInteriorScale.ActorDisplay.standingScale
        body.yScale = OfficeInteriorScale.ActorDisplay.standingScale
    }
}
