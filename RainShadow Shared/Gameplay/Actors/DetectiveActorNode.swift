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

    private enum SeatVisualDirection: String, CaseIterable {
        case northEast = "ne"
        case southEast = "se"

        var facing: ActorFacing {
            switch self {
            case .northEast: .northEast
            case .southEast: .southEast
            }
        }
    }

    private struct SeatAnimationTextures {
        let direction: SeatVisualDirection
        let seatedIdle: [SKTexture]
        let standUp: [SKTexture]
    }

    private let contactShadow: SKSpriteNode
    private let contactShadowKind: ContactShadowKind = .party
    private let selectionRing: SKSpriteNode
    /// Standing, transition, and full chairless seated body.
    private let body: SKSpriteNode
    /// Legacy split seated fallback; hidden when the full seated cell is available.
    private let lowerBody: SKSpriteNode
    private let foregroundArms: SKSpriteNode
    /// Scene grade for the neutral bake (office warm / city night cool).
    private var sceneLighting: ActorSceneLighting = .officeInterior
    private let standingIdleTextures: [ActorFacing: [SKTexture]]
    private let seatVisualDirection: SeatVisualDirection
    private let seatedIdleTextures: [SKTexture]
    private let seatedUpperTextures: [SKTexture]
    private let seatedLowerTextures: [SKTexture]
    private let seatedArmTextures: [SKTexture]
    private let standUpTextures: [SKTexture]
    private let walkTextures: [ActorFacing: [SKTexture]]

    /// Local z while seated: torso above the front apron depth band.
    /// Under-apron feet layer stays hidden (it caused the chair-to-floor wood band).
    private static let seatedUpperLocalZ: CGFloat = 90
    private static let seatedLowerLocalZ: CGFloat = 0
    private static let seatedArmsLocalZ: CGFloat = 110
    /// Look ahead along the live route so 16-bin facing leads corners (~0.24 body).
    private static let facingLookAheadDistance: CGFloat = 24
    /// Shared seated/standing presentation size (integer pixels — avoids nearest shimmer).
    private static let frameDisplaySizeConstant = OfficeInteriorScale.ActorDisplay.spriteDisplaySize
    private static let spriteScale = OfficeInteriorScale.ActorDisplay.spriteScale
    private var facing: ActorFacing = .northEast
    /// The engine's `NewOrientation`: a facing the actor is rotating toward one
    /// bin per tick while standing. Nil once the turn completes.
    private var pendingFacing: ActorFacing?
    private(set) var state: State = .seatedIdle
    private var pendingWalk: (path: [CGPoint], completion: (() -> Void)?)?
    private var needsSeatEgress = true
    private var routeFollower = RouteFollower()
    private var movementCompletion: (() -> Void)?
    private var lastLocomotionUpdateTime: TimeInterval?
    private var tickClock = LogicTickClock()
    private var walkFrameIndex = 0
    /// Ticks left in a `Movable::Backoff` wait. The route is kept intact; only
    /// stepping is suspended, so the walk resumes on the same path.
    private var backoffTicksRemaining = 0

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

    /// True while the visual body is still at the desk kneehole (seated, stand/sit
    /// transition, or seat egress). Keeps apron depth and above-apron body z so
    /// the full-body stand-up strip does not bury behind the SW apron.
    var isDeskRegistered: Bool {
        switch state {
        case .seatedIdle, .sittingDown, .standingUp:
            return true
        case .standingIdle, .walking:
            if body.action(forKey: "seatEgress") != nil {
                return true
            }
            // Still settling out of the seated local offset toward the walk root.
            // Offset may be positive Y (chair-side root → kneehole) or include a
            // desk-lean nudge; magnitude covers both signs.
            let seatMagnitude = hypot(body.position.x, body.position.y)
            let expected = abs(OfficeInteriorScale.ActorDisplay.seatedYOffset)
            return seatMagnitude > max(2, expected * 0.15)
        }
    }

    override init() {
        standingIdleTextures = Dictionary(uniqueKeysWithValues: ActorFacing.allCases.compactMap { facing -> (ActorFacing, [SKTexture])? in
            for sourceName in facing.textureSourceCandidates {
                let textures = (0..<4).compactMap {
                    GameArt.texture(named: String(format: "voss_standing_idle_%@_%02d", sourceName, $0))
                }
                if textures.count == 4 {
                    return (facing, textures)
                }
            }
            return nil
        })
        // The desk's primary view is NE. If that authored set is incomplete,
        // choose the complete SE set as one atomic fallback; never mix directions
        // between cells or between the seated and transition clips.
        let seatAnimations = Self.loadSeatAnimationTextures()
        seatVisualDirection = seatAnimations.direction
        seatedIdleTextures = seatAnimations.seatedIdle
        standUpTextures = seatAnimations.standUp
        seatedUpperTextures = Self.completeSeatTextureSequence(
            prefix: "voss_seated_upper",
            direction: seatAnimations.direction,
            frameCount: 8
        ) ?? []
        seatedLowerTextures = Self.completeSeatTextureSequence(
            prefix: "voss_seated_lower",
            direction: seatAnimations.direction,
            frameCount: 8
        ) ?? []
        seatedArmTextures = Self.completeSeatTextureSequence(
            prefix: "voss_seated_arms",
            direction: seatAnimations.direction,
            frameCount: 8
        ) ?? []
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
        // Soft contact shadow is a separate sprite (not baked into walk/sit frames).
        contactShadow = ContactShadowFactory.make(kind: contactShadowKind)

        selectionRing = SelectionRingFactory.make(
            kind: .party,
            displaySize: contactShadowKind.displaySize,
            position: contactShadowKind.footPosition,
            scale: OfficeInteriorScale.ActorDisplay.standingScale
        )

        let initialSeated = seatedIdleTextures.first
            ?? seatedUpperTextures.first
            ?? standingIdleTextures[seatAnimations.direction.facing]?.first
        if let texture = initialSeated {
            body = SKSpriteNode(texture: texture, size: Self.frameDisplaySizeConstant)
        } else {
            let ratio = OfficeInteriorScale.ActorDisplay.visualBodyRatio
            body = SKSpriteNode(
                color: SKColor(red: 0.12, green: 0.1, blue: 0.1, alpha: 1),
                size: CGSize(width: 76 * ratio, height: 142 * ratio)
            )
        }
        body.anchorPoint = CGPoint(x: 0.5, y: 40 / 256)
        body.texture?.filteringMode = .nearest

        if let texture = seatedLowerTextures.first {
            lowerBody = SKSpriteNode(texture: texture, size: Self.frameDisplaySizeConstant)
        } else {
            lowerBody = SKSpriteNode()
        }
        lowerBody.anchorPoint = body.anchorPoint
        lowerBody.texture?.filteringMode = .nearest
        lowerBody.zPosition = Self.seatedLowerLocalZ

        if let texture = seatedArmTextures.first {
            foregroundArms = SKSpriteNode(texture: texture, size: Self.frameDisplaySizeConstant)
        } else {
            foregroundArms = SKSpriteNode()
        }
        foregroundArms.anchorPoint = body.anchorPoint
        foregroundArms.texture?.filteringMode = .nearest
        // Hands sit above the desk-top occluder so they rest on the writing surface.
        foregroundArms.zPosition = Self.seatedArmsLocalZ

        super.init()
        facing = seatVisualDirection.facing
        addChild(contactShadow)
        addChild(selectionRing)
        addChild(lowerBody)
        addChild(body)
        addChild(foregroundArms)
        assertFrameDisplaySizes()
        applySeatedPose(animated: false)
        applySceneLighting(.officeInterior)
        startSeatedIdle()
    }

    /// Pull the neutral-baked body into the current scene’s value/colour grade.
    /// Call from the hosting scene after spawn (office interior vs city night).
    func applySceneLighting(_ lighting: ActorSceneLighting) {
        sceneLighting = lighting
        for layer in [body, lowerBody, foregroundArms] {
            layer.color = lighting.bodyTint
            layer.colorBlendFactor = lighting.bodyBlend
        }
        selectionRing.alpha = lighting.selectionRingAlpha
        // Keep seated shadow hidden; only refresh weight when already planted.
        if contactShadow.alpha > 0.02 {
            contactShadow.alpha = contactStandingAlpha
        }
    }

    /// Standing contact-shadow opacity after scene scale (wet streets read denser).
    private var contactStandingAlpha: CGFloat {
        contactShadowKind.standingAlpha * sceneLighting.contactShadowAlphaScale
    }

    /// Fixed presentation size for every posture — atlas shared-scale carries crouch height.
    private var frameDisplaySize: CGSize { Self.frameDisplaySizeConstant }

    /// Keeps every actor layer at the fixed display size after texture swaps.
    /// Sit frames vary in opaque height on a 512 canvas; if a node size drifts,
    /// `animate(resize: false)` stretches each cell differently and reads as pulse.
    private func assertFrameDisplaySizes() {
        let size = frameDisplaySize
        body.size = size
        if lowerBody.texture != nil {
            lowerBody.size = size
        }
        if foregroundArms.texture != nil {
            foregroundArms.size = size
        }
    }

    private func applySpriteScale(mirrored: Bool = false) {
        let scale = mirrored ? -Self.spriteScale : Self.spriteScale
        body.xScale = scale
        body.yScale = Self.spriteScale
    }

    /// Frame advance that re-asserts the fixed display size on every cell.
    /// Prefer this over `SKAction.animate` for sit/stand so trimmed vs full-canvas
    /// atlas cells cannot drift the node size mid-clip.
    private func animateFixedSize(on node: SKSpriteNode, textures: [SKTexture], timePerFrame: TimeInterval) -> SKAction {
        textures.forEach { $0.filteringMode = .nearest }
        let steps: [SKAction] = textures.map { texture in
            .sequence([
                .run { [weak self, weak node] in
                    guard let self, let node else { return }
                    node.texture = texture
                    node.texture?.filteringMode = .nearest
                    self.assertFrameDisplaySizes()
                },
                .wait(forDuration: timePerFrame)
            ])
        }
        return .sequence(steps)
    }

    private static func completeSeatTextureSequence(
        prefix: String,
        direction: SeatVisualDirection,
        frameCount: Int
    ) -> [SKTexture]? {
        var textures: [SKTexture] = []
        textures.reserveCapacity(frameCount)
        for index in 0..<frameCount {
            let name = String(format: "%@_%@_%02d", prefix, direction.rawValue, index)
            guard let texture = GameArt.texture(named: name) else { return nil }
            textures.append(texture)
        }
        return textures
    }

    private static func loadSeatAnimationTextures() -> SeatAnimationTextures {
        // Case order intentionally makes the office's NE desk view primary.
        for direction in SeatVisualDirection.allCases {
            guard let seatedIdle = completeSeatTextureSequence(
                prefix: "voss_seated_idle",
                direction: direction,
                frameCount: 8
            ), let standUp = completeSeatTextureSequence(
                prefix: "voss_stand_up",
                direction: direction,
                frameCount: 12
            ) else { continue }
            return SeatAnimationTextures(
                direction: direction,
                seatedIdle: seatedIdle,
                standUp: standUp
            )
        }
        return SeatAnimationTextures(direction: .northEast, seatedIdle: [], standUp: [])
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

    /// BG:EE Shift+click / long-press queue — append waypoints without discarding the active route.
    /// Completion replaces any previous end-of-queue callback and fires only when the full queue empties.
    func walk(appending path: [CGPoint], completion: (() -> Void)? = nil) {
        if state == .standingUp || state == .sittingDown || state == .seatedIdle {
            // No live route yet — a queue append with nothing to append onto is a replace.
            if routeFollower.isMoving == false, pendingWalk == nil {
                walk(path: path, completion: completion)
                return
            }
            if var pending = pendingWalk {
                pending.path.append(contentsOf: path)
                pendingWalk = (pending.path, completion ?? pending.completion)
            } else {
                pendingWalk = (path, completion)
            }
            if state == .seatedIdle {
                ensureStanding { [weak self] in
                    guard let self else { return }
                    guard let pendingWalk = self.pendingWalk else {
                        self.startStandingIdle()
                        return
                    }
                    self.pendingWalk = nil
                    self.beginWalking(path: pendingWalk.path, completion: pendingWalk.completion)
                }
            }
            return
        }

        if state != .walking {
            beginWalking(path: path, completion: completion)
            return
        }

        routeFollower.appendRoute(path)
        if let completion {
            movementCompletion = completion
        }
        guard routeFollower.isMoving else {
            finishWalking()
            return
        }
        let look = routeFollower.lookAheadVector(
            from: position,
            minimumDistance: Self.facingLookAheadDistance
        )
        if look != .zero {
            setFacing(dx: look.dx, dy: look.dy)
        } else if let first = routeFollower.waypoints.first {
            setFacing(dx: first.x - position.x, dy: first.y - position.y)
        }
    }

    var movementDestination: CGPoint? {
        pendingWalk?.path.last ?? routeFollower.destination
    }

    /// Unit screen-space heading toward the next waypoint, `.zero` when idle.
    /// Used for the engine's along-the-path collision probe, which looks ahead
    /// of the mover rather than around it.
    var currentHeading: CGVector {
        let look = routeFollower.lookAheadVector(from: position, minimumDistance: 1)
        let length = hypot(look.dx, look.dy)
        guard length > CGFloat.ulpOfOne else { return .zero }
        return CGVector(dx: look.dx / length, dy: look.dy / length)
    }

    /// True while a replace or append walk order is active (including seat-egress / stand-up wait).
    var isLocomoting: Bool {
        pendingWalk != nil || routeFollower.isMoving || state == .walking
    }

    /// Remaining live route polyline (empty while seated / idle). Used by
    /// corrective repath to compare lengths and detect blocked legs.
    var remainingRouteWaypoints: [CGPoint] {
        if let pending = pendingWalk {
            return pending.path
        }
        return routeFollower.waypoints
    }

    /// World-space length of the remaining live route from the current position.
    var remainingRouteLength: CGFloat {
        if let pending = pendingWalk {
            guard let first = pending.path.first else { return 0 }
            var length = hypot(first.x - position.x, first.y - position.y)
            var previous = first
            for point in pending.path.dropFirst() {
                length += hypot(point.x - previous.x, point.y - previous.y)
                previous = point
            }
            return length
        }
        return routeFollower.remainingPathLength(from: position)
    }

    /// Advances root motion, the walk cycle, and idle turning on the engine's
    /// fixed 15 Hz logic tick. Calling this while the world is paused
    /// intentionally refreshes the timestamp but spends no movement delta, so
    /// opening a modal cannot cause a resume jump.
    ///
    /// Everything happens per tick rather than per rendered frame, mirroring
    /// `Movable::DoStep`: one displacement and one animation frame per tick,
    /// which is why the gait cannot drift against distance travelled.
    func updateLocomotion(at currentTime: TimeInterval, worldIsPaused: Bool) {
        defer { lastLocomotionUpdateTime = currentTime }
        guard !worldIsPaused, let previousTime = lastLocomotionUpdateTime else { return }

        let deltaTime = min(
            max(0, currentTime - previousTime),
            ActorLocomotionPacing.maximumFrameDelta
        )
        guard deltaTime > 0 else { return }

        for _ in 0..<tickClock.drain(deltaTime: deltaTime) {
            switch state {
            case .walking:
                advanceWalkTick()
                // Arrival can fire a completion that starts a scene transition;
                // stop spending ticks the moment we are no longer walking.
                if state != .walking { return }
            case .standingIdle:
                advanceIdleTurnTick()
            case .seatedIdle, .standingUp, .sittingDown:
                return
            }
        }
    }

    /// BG:EE `Movable::Backoff`. When a blocker cannot be bumped the engine
    /// drops to a ready stance and waits a *random* number of ticks before
    /// trying the same step again — GemRB describes the scheme as "inspired by
    /// network media access control algorithms": two actors that block each
    /// other draw different waits and so cannot deadlock in lockstep.
    ///
    /// The route is deliberately left intact; this is a pause, not a cancel.
    func beginMovementBackoff(ticks: Int) {
        guard state == .walking, backoffTicksRemaining == 0 else { return }
        backoffTicksRemaining = max(1, ticks)
        stopWalkAnimation()
    }

    var isBackingOff: Bool { backoffTicksRemaining > 0 }

    private func advanceWalkTick() {
        if backoffTicksRemaining > 0 {
            backoffTicksRemaining -= 1
            return
        }

        let step = routeFollower.advance(
            from: position,
            deltaTime: LogicTickClock.tickDuration,
            speed: ActorLocomotionPacing.walkSpeed
        )
        position = step.position
        if step.direction != .zero {
            let look = routeFollower.lookAheadVector(
                from: position,
                minimumDistance: Self.facingLookAheadDistance
            )
            if look != .zero {
                setFacing(dx: look.dx, dy: look.dy)
            } else {
                setFacing(dx: step.direction.dx, dy: step.direction.dy)
            }
            advanceWalkFrame()
        }
        if step.didArrive {
            finishWalking()
        }
    }

    /// One 22.5° bin per tick toward `pendingFacing`, the engine's gradual turn
    /// for standing creatures. The breath loop is suspended for the duration so
    /// it does not fight the per-bin texture swap, then restarted on arrival.
    private func advanceIdleTurnTick() {
        guard let pending = pendingFacing else { return }
        guard facing != pending else {
            pendingFacing = nil
            return
        }

        body.removeAction(forKey: "standingIdle")
        facing = facing.stepped(toward: pending)
        applyStandingIdleTexture()

        if facing == pending {
            pendingFacing = nil
            startStandingIdle()
        }
    }

    /// Requests the engine's "slow" orientation change toward a world point —
    /// `Movable::SetOrientation(..., slow: true)`, which BG uses when a
    /// conversation starts and when you click the tile you already occupy.
    /// Ignored unless standing: a walking creature takes its facing from the path.
    func turnToFace(_ point: CGPoint) {
        guard state == .standingIdle else { return }
        let dx = point.x - position.x
        let dy = point.y - position.y
        guard dx != 0 || dy != 0 else { return }

        let target = ActorFacing.resolve(dx: dx, dy: dy, retaining: facing, hysteresis: 0)
        pendingFacing = target == facing ? nil : target
    }

    /// BG-style Stop/right-click behavior. A cancelled approach never invokes
    /// its interaction or scene-transition completion.
    func cancelMovement() {
        pendingWalk = nil
        routeFollower.cancel()
        backoffTicksRemaining = 0
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
        restoreStandingContactShadow(animated: false)
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
        pendingFacing = nil
        backoffTicksRemaining = 0
        tickClock.reset()
        needsSeatEgress = false
        state = .standingIdle
        body.position = .zero
        body.zPosition = 0
        body.zRotation = 0
        hideLowerBody()
        foregroundArms.isHidden = true
        foregroundArms.alpha = 0
        restoreStandingContactShadow(animated: false)
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
            let look = routeFollower.lookAheadVector(
                from: position,
                minimumDistance: Self.facingLookAheadDistance
            )
            if look != .zero {
                setFacing(dx: look.dx, dy: look.dy)
            } else {
                setFacing(dx: first.x - position.x, dy: first.y - position.y)
            }
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
        backoffTicksRemaining = 0
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
        facing = seatVisualDirection.facing
        body.removeAction(forKey: "seatedIdle")
        lowerBody.removeAction(forKey: "seatedIdle")
        foregroundArms.removeAction(forKey: "seatedIdle")
        // Collapse to a single full-body layer for the stand-up strip, kept above
        // the kneehole apron until seat egress clears the chair offset.
        body.texture = seatedIdleTextures.first ?? body.texture
        body.zPosition = Self.seatedUpperLocalZ
        hideLowerBody()
        foregroundArms.run(
            .sequence([.fadeOut(withDuration: 0.12), .hide()]),
            withKey: "standTransition"
        )
        let finishStanding = SKAction.run { [weak self] in
            guard let self else { return }
            self.facing = self.seatVisualDirection.facing
            self.applyStandingIdleTexture()
            self.body.zPosition = Self.seatedUpperLocalZ
            self.assertFrameDisplaySizes()
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
        assertFrameDisplaySizes()
        let standUp = animateFixedSize(
            on: body,
            textures: standUpTextures,
            timePerFrame: ActorLocomotionPacing.standUpSecondsPerFrame
        )
        body.run(.sequence([standUp, finishStanding]), withKey: "standTransition")
    }

    /// Plays the stand-up clip in exact reverse and re-enters the seated desk
    /// idle. A walk order issued mid-sit queues and replays the stand-up chain
    /// once the actor has settled.
    func sitDown(completion: (() -> Void)? = nil) {
        guard state == .standingIdle else {
            completion?()
            return
        }
        state = .sittingDown
        body.removeAction(forKey: "standingIdle")
        facing = seatVisualDirection.facing
        body.zPosition = Self.seatedUpperLocalZ
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

        let sitDownTextures = Array(standUpTextures.reversed())
        guard sitDownTextures.count == 12 else {
            body.run(
                .sequence([.fadeOut(withDuration: 0.08), finishSitting, .fadeIn(withDuration: 0.12)]),
                withKey: "standTransition"
            )
            return
        }

        sitDownTextures.forEach { $0.filteringMode = .nearest }
        let duration = ActorLocomotionPacing.standUpSecondsPerFrame * TimeInterval(sitDownTextures.count)
        assertFrameDisplaySizes()
        let sitDown = animateFixedSize(
            on: body,
            textures: sitDownTextures,
            timePerFrame: ActorLocomotionPacing.standUpSecondsPerFrame
        )
        let nudge = OfficeInteriorScale.ActorDisplay.seatedDeskNudge
        let reach = OfficeInteriorScale.ActorDisplay.seatedUpperDeskReach
        let seat = CGPoint(
            x: nudge.x,
            y: OfficeInteriorScale.ActorDisplay.seatedYOffset + nudge.y
        )
        let upperSeat = CGPoint(x: seat.x + reach.x, y: seat.y + reach.y)
        let settle = SKAction.move(to: upperSeat, duration: duration)
        settle.timingMode = .linear
        body.xScale = Self.spriteScale
        body.yScale = Self.spriteScale
        contactShadow.run(.fadeOut(withDuration: duration * 0.5))
        body.run(.sequence([.group([sitDown, settle]), finishSitting]), withKey: "standTransition")
    }

    private func animateSeatEgress(duration: TimeInterval, completion: (() -> Void)? = nil) {
        body.removeAction(forKey: "seatEgress")
        lowerBody.removeAction(forKey: "seatEgress")
        // Stay above the apron while the visual root leaves the kneehole.
        body.zPosition = Self.seatedUpperLocalZ
        let settleBody = SKAction.move(to: .zero, duration: duration)
        settleBody.timingMode = .linear
        body.run(
            .sequence([
                settleBody,
                .run { [weak self] in
                    self?.body.zPosition = 0
                    completion?()
                }
            ]),
            withKey: "seatEgress"
        )
        lowerBody.run(settleBody, withKey: "seatEgress")

        contactShadow.removeAllActions()
        let footY = contactShadowKind.footPosition.y
        let settleShadow = SKAction.moveTo(y: footY, duration: duration)
        settleShadow.timingMode = .linear
        contactShadow.run(
            .group([
                settleShadow,
                .sequence([
                    .wait(forDuration: duration * 0.45),
                    ContactShadowFactory.fadeToStanding(
                        contactShadow,
                        to: contactStandingAlpha,
                        duration: duration * 0.55
                    )
                ])
            ]),
            withKey: "seatEgress"
        )
    }

    /// Plant the soft floor blob at the walkable foot pivot with standing weight.
    private func restoreStandingContactShadow(animated: Bool) {
        contactShadow.removeAllActions()
        let scale = OfficeInteriorScale.ActorDisplay.standingScale
        contactShadow.position = contactShadowKind.footPosition
        contactShadow.xScale = scale * 1.06
        contactShadow.yScale = scale
        if animated {
            contactShadow.run(
                ContactShadowFactory.fadeToStanding(
                    contactShadow,
                    to: contactStandingAlpha,
                    duration: 0.2
                )
            )
        } else {
            contactShadow.alpha = contactStandingAlpha
        }
    }

    private func hideLowerBody() {
        lowerBody.removeAllActions()
        lowerBody.isHidden = true
        lowerBody.alpha = 0
        lowerBody.zPosition = Self.seatedLowerLocalZ
    }

    private func applySeatedPose(animated: Bool) {
        let nudge = OfficeInteriorScale.ActorDisplay.seatedDeskNudge
        let reach = OfficeInteriorScale.ActorDisplay.seatedUpperDeskReach
        let seat = CGPoint(
            x: nudge.x,
            y: OfficeInteriorScale.ActorDisplay.seatedYOffset + nudge.y
        )
        let upperSeat = CGPoint(x: seat.x + reach.x, y: seat.y + reach.y)
        // The full seated cell owns Voss only; the separate world prop owns the
        // chair throughout idle, transitions, egress, and walking. The legacy
        // split upper/lower fallback remains hidden at the desk.
        body.texture = seatedIdleTextures.first
            ?? seatedUpperTextures.first
            ?? standingIdleTextures[seatVisualDirection.facing]?.first
        body.zPosition = Self.seatedUpperLocalZ
        hideLowerBody()
        body.texture?.filteringMode = .nearest
        body.xScale = Self.spriteScale
        body.yScale = Self.spriteScale
        body.position = upperSeat
        // NE rear view bakes hands into the body cell.
        foregroundArms.texture = seatedArmTextures.first
        foregroundArms.texture?.filteringMode = .nearest
        foregroundArms.xScale = Self.spriteScale
        foregroundArms.yScale = Self.spriteScale
        foregroundArms.position = upperSeat
        foregroundArms.zPosition = Self.seatedArmsLocalZ
        foregroundArms.alpha = 0
        foregroundArms.isHidden = true
        let scale = OfficeInteriorScale.ActorDisplay.standingScale
        contactShadow.xScale = scale * 1.06
        contactShadow.yScale = scale
        contactShadow.position = CGPoint(
            x: seat.x + contactShadowKind.footPosition.x,
            y: seat.y + contactShadowKind.footPosition.y
        )
        // The seated baseline is visually registered behind the desk. A ground
        // contact shadow at that offset projects onto the desktop, so keep it
        // hidden until the first walking leg carries it to the walkable floor root.
        contactShadow.alpha = 0
        assertFrameDisplaySizes()
    }

    /// Ping-pong breath indices for an authored strip (e.g. 8 frames -> 0...7...1).
    private static func breathCycleIndices(frameCount: Int) -> [Int] {
        guard frameCount > 1 else { return Array(0..<max(1, frameCount)) }
        return Array(0..<frameCount) + Array((1..<(frameCount - 1)).reversed())
    }

    private func startSeatedIdle() {
        assertFrameDisplaySizes()
        guard seatedIdleTextures.count > 1 else { return }
        let indices = Self.breathCycleIndices(frameCount: seatedIdleTextures.count)
        let breathCycle = indices.map { seatedIdleTextures[$0] }
        let animate = animateFixedSize(on: body, textures: breathCycle, timePerFrame: 0.21)
        body.run(.repeatForever(animate), withKey: "seatedIdle")
    }

    private func startStandingIdle() {
        body.removeAction(forKey: "standingIdle")
        applyStandingIdleTexture()
        assertFrameDisplaySizes()
        if let frames = standingIdleTextures[facing], frames.count > 1 {
            // Authored 4-frame breath loop with a long neutral hold, replacing
            // the former single-frame position bob.
            frames.forEach { $0.filteringMode = .nearest }
            let indices = Self.breathCycleIndices(frameCount: frames.count)
            let breath = animateFixedSize(
                on: body,
                textures: indices.map { frames[$0] },
                timePerFrame: 0.42
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

    /// Walking facing, which snaps — `DoStep` assigns the path node's
    /// orientation with `slow: false`, setting current and pending together, so
    /// any queued gradual turn is superseded.
    private func setFacing(dx: CGFloat, dy: CGFloat) {
        let nextFacing = ActorFacing.resolve(dx: dx, dy: dy, retaining: facing)
        facing = nextFacing
        pendingFacing = nil
        applyWalkTexture()
    }

    private func applyWalkTexture() {
        applySpriteScale(mirrored: facing.isMirrored)
        body.zRotation = 0
        guard let textures = walkTextures[facing], !textures.isEmpty else { return }
        textures.forEach { $0.filteringMode = .nearest }
        walkFrameIndex %= textures.count
        body.texture = textures[walkFrameIndex]
        assertFrameDisplaySizes()
    }

    /// Exactly one authored frame per logic tick, as the engine advances a
    /// creature animation inside `DoStep`. There is deliberately no accumulator:
    /// sharing the movement tick is what keeps the cycle locked to travel.
    private func advanceWalkFrame() {
        guard let textures = walkTextures[facing], !textures.isEmpty else { return }
        walkFrameIndex = (walkFrameIndex + 1) % textures.count
        applyWalkTexture()
    }

    private func stopWalkAnimation() {
        applyStandingIdleTexture()
        body.position.y = 0
        body.zRotation = 0
    }

    private func applyStandingIdleTexture() {
        if let idleTexture = standingIdleTextures[facing]?.first {
            body.texture = idleTexture
            body.texture?.filteringMode = .nearest
        }
        applySpriteScale(mirrored: facing.isMirrored)
        assertFrameDisplaySizes()
    }
}
