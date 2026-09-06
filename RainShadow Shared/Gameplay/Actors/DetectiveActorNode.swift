import SpriteKit

@MainActor
final class DetectiveActorNode: SKNode, WallStencilledActor {
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
        case north = "n"

        var facing: ActorFacing {
            switch self {
            // The approved NE desk masters use the stored NW-handed rear view.
            // Keep that handedness for the standing-idle handoff; selecting
            // ActorFacing.northEast would mirror the NW standing cell and make
            // Voss snap to the opposite diagonal after rising.
            case .northEast: .northWest
            case .southEast: .southEast
            case .north: .north
            }
        }
    }

    private struct SeatAnimationFrames {
        let direction: SeatVisualDirection
        let seatedIdle: [IEAvatarVisualFrame]
        let standUp: [IEAvatarVisualFrame]
    }

    private let contactShadow: SKSpriteNode
    private let contactShadowKind: ContactShadowKind = .party
    private let groundCircle = GroundCircleNode()
    /// `Selectable`'s ground-circle state. The detective is the party, so she is
    /// `EA_PC` and selected from the start (GemRB `Game::SelectActor`); there is
    /// no second party member to hand the selection to yet.
    var groundCircleState = GroundCircleState(enmity: .pc, isPC: true, isSelected: true)
    /// Standing, transition, and full chairless seated body.
    private let body: IEAvatarNode
    /// Legacy split seated fallback; hidden when the full seated cell is available.
    private let lowerBody: IEAvatarNode
    private let foregroundArms: IEAvatarNode
    /// Retains the validated indexed payload and its resolved-texture cache.
    private let avatarLibrary: IEAvatarFrameLibrary?
    /// Scene grade for the neutral bake (office warm / city night cool).
    private var sceneLighting: ActorSceneLighting = .officeInterior
    /// Optional lightmap sample under the feet, mixed into the scene grade.
    private var footLight: AreaLightSample?
    /// Sprite-only elevation from a height map. Feet and search cell stay put.
    var visualHeightOffset: CGFloat = 0 {
        didSet { applyVisualHeightOffset() }
    }
    private let standingIdleFrames: [ActorFacing: [IEAvatarVisualFrame]]
    private let seatVisualDirection: SeatVisualDirection
    private let seatedIdleFrames: [IEAvatarVisualFrame]
    private let seatedUpperFrames: [IEAvatarVisualFrame]
    private let seatedLowerFrames: [IEAvatarVisualFrame]
    private let seatedArmFrames: [IEAvatarVisualFrame]
    private let standUpFrames: [IEAvatarVisualFrame]
    private let walkFrames: [ActorFacing: [IEAvatarVisualFrame]]

    /// Local z while seated: torso above the front apron depth band.
    /// Under-apron feet layer stays hidden (it caused the chair-to-floor wood band).
    private static let seatedUpperLocalZ: CGFloat = 90
    private static let seatedLowerLocalZ: CGFloat = 0
    private static let seatedArmsLocalZ: CGFloat = 110
    /// Look ahead along the live route so 16-bin facing leads corners (~0.24 body).
    private static let facingLookAheadDistance: CGFloat = 24
    /// Full-canvas atlas fallback pivot; indexed frames carry their cropped pivot.
    private static let compatibilityAnchor = CGPoint(x: 0.5, y: 40 / 256)
    private static let spriteScale = OfficeInteriorScale.ActorDisplay.spriteScale
    private var facing: ActorFacing = .northEast
    /// The engine's `NewOrientation`: a facing the actor is rotating toward one
    /// bin per tick while standing. Nil once the turn completes.
    /// This actor's BG:EE `move_scale` and any rate modifiers. Ships at
    /// `humanoid` (9), which is the engine's one constant human rate.
    var movementProfile: MovementProfile = .humanoid

    /// Which footstep set this actor's floor uses. Scenes set it; see
    /// `FootstepSurface` for why the seam exists.
    var footstepSurface: FootstepSurface = .floorboard
    /// Silences footsteps and barks without stopping locomotion — used for the
    /// scripted cutscene walks, where BG also keeps the world quiet.
    var isAudioSilenced = false
    private var footsteps = FootstepCadence()
    private var footstepVariant = 0
    private var idleClock = IdleBehaviourClock(phase: 3)
    private var pendingFacing: ActorFacing?
    private(set) var state: State = .seatedIdle
    private var pendingWalk: (path: Path, completion: (() -> Void)?)?
    private var needsSeatEgress = true
    /// The engine's `Movable`: path, orientation, bump and backoff state.
    /// Exposed so `MovementOrderQueue` can issue orders into it the way
    /// `GameControl` does — the queue is policy, this is the actor.
    var movable = Movable(identity: "detective", position: .zero)
    private var movementCompletion: (() -> Void)?
    private var lastLocomotionUpdateTime: TimeInterval?
    private var tickClock = LogicTickClock()
    /// The engine's `Game::Ticks` for this actor. `DoStep` refuses more than one
    /// step per tick value and `WalkTo` rate-limits against it, so both need a
    /// counter that only ever increases.
    private(set) var currentTick = 0
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
        let __traceStart = AreaLoadTrace.isEchoing ? CFAbsoluteTimeGetCurrent() : 0
        defer { AreaLoadTrace.note("init.DetectiveActorNode", milliseconds: (CFAbsoluteTimeGetCurrent() - __traceStart) * 1_000) }
        let indexedLibrary = try? IEAvatarFrameLibrary.shared(character: "Voss")
        avatarLibrary = indexedLibrary
        standingIdleFrames = Dictionary(uniqueKeysWithValues: ActorFacing.allCases.compactMap { facing -> (ActorFacing, [IEAvatarVisualFrame])? in
            for sourceName in facing.textureSourceCandidates {
                if let frames = Self.completeFrameSequence(
                    library: indexedLibrary,
                    atlas: "VossIdle.atlas",
                    prefix: "voss_standing_idle",
                    direction: sourceName,
                    frameCount: 4
                ) {
                    return (facing, frames)
                }
            }
            return nil
        })
        // The desk's primary view is NE. If that authored set is incomplete,
        // choose the next complete set as one atomic fallback; never mix
        // directions between cells or between the seated and transition clips.
        let seatAnimations = Self.loadSeatAnimationFrames(library: indexedLibrary)
        seatVisualDirection = seatAnimations.direction
        seatedIdleFrames = seatAnimations.seatedIdle
        standUpFrames = seatAnimations.standUp
        seatedUpperFrames = Self.completeSeatFrameSequence(
            library: indexedLibrary,
            atlas: "VossSeatedIdle.atlas",
            prefix: "voss_seated_upper",
            direction: seatAnimations.direction,
            frameCount: 8
        ) ?? []
        seatedLowerFrames = Self.completeSeatFrameSequence(
            library: indexedLibrary,
            atlas: "VossSeatedIdle.atlas",
            prefix: "voss_seated_lower",
            direction: seatAnimations.direction,
            frameCount: 8
        ) ?? []
        seatedArmFrames = Self.completeSeatFrameSequence(
            library: indexedLibrary,
            atlas: "VossSeatedArms.atlas",
            prefix: "voss_seated_arms",
            direction: seatAnimations.direction,
            frameCount: 8
        ) ?? []
        walkFrames = Dictionary(uniqueKeysWithValues: ActorFacing.allCases.compactMap { facing -> (ActorFacing, [IEAvatarVisualFrame])? in
            for sourceName in facing.textureSourceCandidates {
                if let frames = Self.completeFrameSequence(
                    library: indexedLibrary,
                    atlas: "VossWalk.atlas",
                    prefix: "voss_walk",
                    direction: sourceName,
                    frameCount: ActorLocomotionPacing.walkFramesPerCycle
                ) {
                    return (facing, frames)
                }
            }
            return nil
        })

        // V15 atlases carry a 200px body rasterised at plate density (2.84
        // art-px/wu vs the office plate's 2.53), so sprite and floor share one
        // raster like BG:EE. Linear filtering smooths the play-zoom
        // magnification the same way the EE engine smooths its zoom.
        // Soft contact shadow is a separate sprite (not baked into walk/sit frames).
        contactShadow = ContactShadowFactory.make(kind: contactShadowKind)
        // Embedded index-1 cast shadows own their opacity through IEIndexedSprite.
        // Hide the fallback independently of seat actions that animate its alpha.
        contactShadow.isHidden = indexedLibrary?.sprite.hasEmbeddedShadow == true

        let initialSeated = seatedIdleFrames.first
            ?? seatedUpperFrames.first
            ?? standingIdleFrames[seatAnimations.direction.facing]?.first
        body = IEAvatarNode(frame: initialSeated)
        if initialSeated == nil {
            let ratio = OfficeInteriorScale.ActorDisplay.visualBodyRatio
            body.color = SKColor(red: 0.12, green: 0.1, blue: 0.1, alpha: 1)
            body.size = CGSize(width: 76 * ratio, height: 142 * ratio)
            body.anchorPoint = Self.compatibilityAnchor
        }

        lowerBody = IEAvatarNode(frame: seatedLowerFrames.first)
        lowerBody.zPosition = Self.seatedLowerLocalZ

        foregroundArms = IEAvatarNode(frame: seatedArmFrames.first)
        // Hands sit above the desk-top occluder so they rest on the writing surface.
        foregroundArms.zPosition = Self.seatedArmsLocalZ

        super.init()
        facing = seatVisualDirection.facing
        addChild(contactShadow)
        addChild(groundCircle)
        addChild(lowerBody)
        addChild(body)
        addChild(foregroundArms)
        applySeatedPose(animated: false)
        applySceneLighting(.officeInterior)
        startSeatedIdle()
    }

    func applyFootLight(_ sample: AreaLightSample) {
        footLight = sample
        applyBodyTint()
    }


    private var tintedLayers: [IEAvatarNode] { [body, lowerBody, foregroundArms] }

    /// `Map::DrawMap`'s per-actor tint, transliterated:
    ///
    /// ```cpp
    /// Color baseTint = area->GetLighting(actor->Pos);
    /// Color tint(baseTint);
    /// game->ApplyGlobalTint(tint, flags);
    /// actor->Draw(viewport, baseTint, tint, flags | BlitFlags::BLENDED);
    /// ```
    ///
    /// The `0.45 + 0.55 * footLight` curve this replaces was invented, and so
    /// was applying it through `colorBlendFactor` — a lerp *toward* a colour,
    /// which brightens a dark pixel instead of darkening it. `ShaderTint` is a
    /// multiply and can only ever darken, which is what seats a character in an
    /// unlit room rather than floating them over it.
    private func applyBodyTint() {
        var flags: IEBlitFlags = .blended
        var tint = IEColor.opaqueWhite
        if let footLight {
            // `GetLighting`. With no lightmap the engine's equivalent is no
            // tint at all, not a white one — hence the flag rather than a value.
            flags.insert(.colorMod)
            tint = footLight.ieColor
        }
        IEBlit.applyGlobalTint(&tint, &flags, global: sceneLighting.globalTint)
        // `Map::DrawMap` ORs the per-object state flags in before drawing —
        // `if (game->TimeStoppedFor(actor)) flags |= BlitFlags::GREY;`. Reading
        // the scene rather than caching a copy is deliberate: this runs on every
        // step, and a cached copy is a second thing to keep in step with the pause.
        flags.formUnion((scene as? BaseGameScene)?.worldBlitFlags ?? [])

        for layer in tintedLayers {
            IEBlitShader.update(layer.blitShader, tint: tint, flags: flags)
            guard layer.shader !== layer.blitShader else { continue }
            layer.shader = layer.blitShader
            // The lerp this replaces. Leaving it set would grade twice, once in
            // SpriteKit and once in the shader.
            layer.colorBlendFactor = 0
        }
        if contactShadow.alpha > 0.02 {
            contactShadow.alpha = contactStandingAlpha
        }
    }

    /// Where the body sits when Voss is standing on his own ground point.
    ///
    /// `applySeatedPose` is the only thing that displaces it, and the seat
    /// offset is `seatedDeskNudge` **plus** `seatedYOffset` — horizontal as
    /// well as vertical. Every restore below used to assign `.y` alone, so once
    /// an egress did not run to completion the `-20` nudge stayed on `.x` for
    /// the rest of the session: Voss drawn twenty units to the left of the
    /// point he actually occupied, `isDeskRegistered` stuck true because it
    /// measures `hypot(body.position…)`, and no ground circle, because there
    /// was no longer a body standing on the point the circle marks.
    ///
    /// `visualHeightOffset` is the standing `y`, not zero: on a height map the
    /// sprite rides the slope while the feet keep their ground point.
    private var standingBodyPosition: CGPoint {
        CGPoint(x: 0, y: visualHeightOffset)
    }

    private func applyVisualHeightOffset() {
        body.position.y = visualHeightOffset
        lowerBody.position.y = visualHeightOffset
        foregroundArms.position.y = visualHeightOffset
    }

    /// Point every layer at the area's baked wall stencil, or clear it.
    ///
    /// `Map::SetDrawingStencilForScriptable` decides this per object per frame
    /// and so does the caller; this is the per-layer half. It replaces
    /// `ActorCover`'s uniform alpha, which dropped the *whole* actor to 0.42
    /// whenever its ground point fell inside a covering outline — where upstream
    /// masks only the pixels the wall actually overlaps, so a character
    /// half-behind a pillar keeps their exposed half opaque.
    func applyWallStencil(_ stencil: WallStencilTexture?, in scene: SKScene) {
        for layer in tintedLayers {
            guard layer.shader === layer.blitShader else { continue }
            if let stencil {
                stencil.apply(to: layer, in: scene)
            } else {
                WallStencilTexture.clear(on: layer)
            }
        }
    }

    /// Pull the neutral-baked body into the current scene’s value/colour grade.
    /// Call from the hosting scene after spawn (office interior vs city night).
    func applySceneLighting(_ lighting: ActorSceneLighting) {
        sceneLighting = lighting
        applyBodyTint()
    }

    /// Standing contact-shadow opacity after scene scale (wet streets read denser).
    private var contactStandingAlpha: CGFloat {
        contactShadowKind.standingAlpha * sceneLighting.contactShadowAlphaScale
    }

    private func applySpriteScale(mirrored: Bool = false) {
        let scale = mirrored ? -Self.spriteScale : Self.spriteScale
        body.xScale = scale
        body.yScale = Self.spriteScale
    }

    /// Indexed frame advance: the crop texture, physical size and foot pivot
    /// change atomically, preserving the old 512-cell registration without
    /// retaining transparent canvas pixels at runtime.
    private func animateFrames(
        on node: IEAvatarNode,
        frames: [IEAvatarVisualFrame],
        timePerFrame: TimeInterval
    ) -> SKAction {
        let steps: [SKAction] = frames.map { frame in
            .sequence([
                .run { [weak node] in
                    node?.apply(frame)
                },
                .wait(forDuration: timePerFrame)
            ])
        }
        return .sequence(steps)
    }

    private static func completeFrameSequence(
        library: IEAvatarFrameLibrary?,
        atlas: String,
        prefix: String,
        direction: String,
        frameCount: Int
    ) -> [IEAvatarVisualFrame]? {
        let stems = (0..<frameCount).map {
            String(format: "%@_%@_%02d", prefix, direction, $0)
        }
        return IEAvatarFrames.sequence(
            library: library,
            atlas: atlas,
            stems: stems,
            compatibilityAnchor: compatibilityAnchor
        )
    }

    private static func completeSeatFrameSequence(
        library: IEAvatarFrameLibrary?,
        atlas: String,
        prefix: String,
        direction: SeatVisualDirection,
        frameCount: Int
    ) -> [IEAvatarVisualFrame]? {
        completeFrameSequence(
            library: library,
            atlas: atlas,
            prefix: prefix,
            direction: direction.rawValue,
            frameCount: frameCount
        )
    }

    private static func loadSeatAnimationFrames(
        library: IEAvatarFrameLibrary?
    ) -> SeatAnimationFrames {
        // Case order intentionally makes the office's NE desk view primary.
        for direction in SeatVisualDirection.allCases {
            guard let seatedIdle = completeSeatFrameSequence(
                library: library,
                atlas: "VossSeatedIdle.atlas",
                prefix: "voss_seated_idle",
                direction: direction,
                frameCount: 8
            ), let standUp = completeSeatFrameSequence(
                library: library,
                atlas: "VossSeatTransitions.atlas",
                prefix: "voss_stand_up",
                direction: direction,
                frameCount: 12
            ) else { continue }
            return SeatAnimationFrames(
                direction: direction,
                seatedIdle: seatedIdle,
                standUp: standUp
            )
        }
        return SeatAnimationFrames(direction: .northEast, seatedIdle: [], standUp: [])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("DetectiveActorNode is created programmatically")
    }

    /// Adopt a prebuilt route — scripted beats and cutscenes, which resolve
    /// their anchors through `NavigationMap.waypoints(visiting:)`.
    func walk(path: Path, completion: (() -> Void)? = nil) {
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
    func walk(appending path: Path, completion: (() -> Void)? = nil) {
        if state == .standingUp || state == .sittingDown || state == .seatedIdle {
            // No live route yet — a queue append with nothing to append onto is a replace.
            if !movable.isMoving, pendingWalk == nil {
                walk(path: path, completion: completion)
                return
            }
            if var pending = pendingWalk {
                pending.path.append(path)
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

        movable.appendPath(path)
        if let completion {
            movementCompletion = completion
        }
        guard movable.isMoving else {
            finishWalking()
            return
        }
        setWalkFacing(movable.orientation)
    }


    /// Hand the engine this actor's position, snapped to whole units.
    ///
    /// `Movable`'s step arithmetic is integral — `NormalizeDeltas` ceils every
    /// axis — and `doStep` decides arrival with an exact `position ==
    /// step.point`. A SpriteKit node position carries the sub-unit remainder of
    /// whatever last wrote it; the office's authored entrance is
    /// (2175.4100329414914, 1079.2861942938816). Whole-unit steps cannot cancel
    /// a fraction, so handing one in makes that equality unreachable and the
    /// walk never reports `arrived`. This is the same boundary snap `findPath`,
    /// `Path.init(points:from:)` and `ticksToReach` already do; see
    /// `CGPoint.rounded`.
    func syncMovablePosition(_ point: CGPoint? = nil) {
        movable.position = (point ?? position).rounded
    }

    /// Hand this actor its area.
    ///
    /// `Movable` needs the map for the three things it does that are not pure
    /// arithmetic: searching (`WalkTo`), looking ahead for a blocker
    /// (`DoStep`), and relocating itself when pushed (`BumpAway`).
    func attachNavigation(_ map: NavigationMap, id: String) {
        movable.map = map
        movable.identity = id
        movable.circleSize = ActorLocomotionPacing.personalSpaceCells
        syncMovablePosition()
    }

    /// Issue a move order the way `GameControl::OnMouseUp` does.
    ///
    /// The order runs against this actor's own `Movable`, so the engine's own
    /// entry points decide everything: `WalkTo` for a fresh order (which plans
    /// around other actors), `AddWayPoint` for an append (which does not), the
    /// same-cell head turn, and the rate limit. The scene gets back what
    /// happened so it can drive pips, barks and the blocked marker.
    ///
    /// A seated actor still takes the order — the search does not care that the
    /// body is sitting — and the resulting path simply waits in the `Movable`
    /// while the stand-up strip plays, because `doStep` is only pumped in the
    /// walking state.
    @discardableResult
    func issueOrder(
        via queue: MovementOrderQueue,
        to target: CGPoint,
        minDistance: CGFloat = 0,
        queueWaypoint: Bool = false,
        completion: (() -> Void)? = nil
    ) -> MovementOrderQueue.Outcome {
        syncMovablePosition()
        let outcome = queue.order(
            &movable,
            to: target,
            minDistance: minDistance,
            queueWaypoint: queueWaypoint,
            ticks: currentTick
        )

        switch outcome {
        case .walk:
            movementCompletion = completion
            if state == .seatedIdle || state == .standingUp || state == .sittingDown {
                ensureStanding { [weak self] in self?.beginOrderedWalk() }
            } else {
                beginOrderedWalk()
            }
        case .append:
            if let completion { movementCompletion = completion }
            if state == .walking { setWalkFacing(movable.orientation) }
        case .alreadyInRange:
            // The scene owns the immediate completion so it can clear pips and
            // turn toward the target before using the object or changing area.
            cancelMovement()
        case .turnInPlace, .refused, .ignored:
            break
        }
        return outcome
    }

    /// Start walking a route the `Movable` is already holding.
    private func beginOrderedWalk() {
        guard movable.isMoving else {
            finishWalking()
            return
        }
        let isCompletingSeatEgress = needsSeatEgress || body.action(forKey: "seatEgress") != nil
        state = .walking
        body.removeAction(forKey: "standingIdle")
        if !isCompletingSeatEgress {
            body.position = standingBodyPosition
            lowerBody.position = .zero
            body.zPosition = 0
            hideLowerBody()
        }
        setWalkFacing(movable.currentNodeOrientation ?? facing)
        if isCompletingSeatEgress, let first = movable.remainingPoints.first {
            needsSeatEgress = false
            let ticks = movable.ticksToReach(first, walkScale: movementProfile.walkScale ?? 0)
            animateSeatEgress(
                duration: max(
                    ActorLocomotionPacing.minimumSegmentDuration,
                    TimeInterval(ticks) * LogicTickClock.tickDuration
                )
            )
        }
    }

    var movementDestination: CGPoint? {
        pendingWalk?.path.destination ?? (movable.isMoving ? movable.destination : nil)
    }

    /// Ordered goals still ahead — what the ground reticles are drawn from.
    /// The engine marks them inside the path itself (`AddWayPoint`), so there is
    /// no separate queue to keep in step.
    var pendingWaypoints: [CGPoint] {
        movable.pendingWaypoints
    }

    /// Unit screen-space heading toward the next waypoint, `.zero` when idle.
    /// Used for the engine's along-the-path collision probe, which looks ahead
    /// of the mover rather than around it.
    var currentHeading: CGVector {
        guard let next = movable.remainingPoints.first else { return .zero }
        let dx = next.x - position.x
        let dy = next.y - position.y
        let length = hypot(dx, dy)
        guard length > CGFloat.ulpOfOne else { return .zero }
        return CGVector(dx: dx / length, dy: dy / length)
    }

    /// True while a replace or append walk order is active (including seat-egress / stand-up wait).
    var isLocomoting: Bool {
        pendingWalk != nil || movable.isMoving || state == .walking
    }

    /// Remaining live route polyline (empty while seated / idle). Used by
    /// corrective repath to compare lengths and detect blocked legs.
    var remainingRouteWaypoints: [CGPoint] {
        if let pending = pendingWalk {
            return pending.path.remainingPoints
        }
        return movable.remainingPoints
    }

    /// Advances root motion, the walk cycle, and idle turning on the engine's
    /// fixed 15 Hz logic tick. Calling this while the world is paused
    /// intentionally refreshes the timestamp but spends no movement delta, so
    /// opening a modal cannot cause a resume jump.
    ///
    /// Everything happens per tick rather than per rendered frame, mirroring
    /// `Movable::DoStep`: one displacement and one animation frame per tick,
    /// which is why the gait cannot drift against distance travelled.
    /// Drops the partial tick when the world resumes.
    ///
    /// `LogicTickClock` keeps a sub-tick remainder on purpose so a 60 Hz render
    /// loop does not lose steps. Across a pause that remainder is stale, and
    /// spending it would move the actor on the frame the player unfreezes.
    func resetLocomotionClock() {
        tickClock.reset()
        lastLocomotionUpdateTime = nil
    }

    func updateLocomotion(at currentTime: TimeInterval, worldIsPaused: Bool) {
        defer { lastLocomotionUpdateTime = currentTime }
        guard !worldIsPaused, let previousTime = lastLocomotionUpdateTime else { return }

        let deltaTime = min(
            max(0, currentTime - previousTime),
            ActorLocomotionPacing.maximumFrameDelta
        )
        guard deltaTime > 0 else { return }

        for _ in 0..<tickClock.drain(deltaTime: deltaTime) {
            currentTick += 1
            switch state {
            case .walking:
                // The engine clears a route in more places than `DoStep`
                // reports: `Movable::WalkTo`'s same-cell head turn, which a
                // corrective repath can reach on the last cell of any walk,
                // clears the path and leaves `movementState == .noMovement`
                // without ever producing a `StepOutcome`. Upstream that is
                // harmless because `ClearPath` drops the stance back to
                // `IE_ANI_AWAKE` and the animation follows the stance; here the
                // node owns its own presentation, so it has to ask. Without
                // this, Voss holds his last walk frame forever.
                //
                // Backing off keeps `movementState == .moving`, and
                // `beginWalking` deliberately parks a stopped movable in
                // `.walking` while the seat-egress slide finishes and calls
                // `finishWalking` from that action's completion — neither is a
                // finished walk.
                guard movable.isMoving
                    || movable.isBackingOff
                    || body.action(forKey: "seatEgress") != nil else {
                    finishWalking()
                    return
                }
                advanceWalkTick()
                // Arrival can fire a completion that starts a scene transition;
                // stop spending ticks the moment we are no longer walking.
                if state != .walking { return }
            case .standingIdle:
                advanceIdleTurnTick()
                advanceIdleBehaviourTick()
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
        guard state == .walking, !movable.isBackingOff else { return }
        movable.backoff()
        stopWalkAnimation()
    }

    var isBackingOff: Bool { movable.isBackingOff }

    /// One `Movable::DoStep`, plus the presentation it drives.
    ///
    /// Facing is taken from the path node the engine just walked toward
    /// (`SetOrientation(step.orient, false)`), never recomputed from velocity —
    /// which is why there is no look-ahead vector and no hysteresis here any
    /// more. The node stores its own orientation, so a walker cannot flicker
    /// across a sector boundary.
    private func advanceWalkTick() {
        syncMovablePosition()
        if movable.isBackingOff {
            movable.decreaseBackoff()
            return
        }

        let outcome = movable.doStep(
            walkScale: movementProfile.walkScale ?? 0,
            time: currentTick
        )
        position = movable.position

        if let blockerID = outcome.bumpedActorID {
            bumpRequest = blockerID
        }
        if outcome.moved {
            setWalkFacing(movable.orientation)
            advanceWalkFrame()
            playFootstepIfDue()
        }
        if outcome.arrived {
            finishWalking()
        } else if outcome.abandoned {
            // Reaching neither the target nor its MinDistance must not use the
            // object or transition the scene merely because locomotion stopped.
            finishWalking(completing: false)
        }
    }

    /// Set by `DoStep` when it decides to push a blocking actor aside. A
    /// `Movable` has no handle on its neighbours, so the scene relays the
    /// `BumpAway()` — which is the one place the engine's in-actor call has to
    /// become a message.
    private(set) var bumpRequest: String?

    func clearBumpRequest() {
        bumpRequest = nil
    }

    /// BG:EE `Actor::PlayWalkSound` — see `FootstepCadence` for why this is gated
    /// on the previous clip finishing rather than on a contact frame.
    private func playFootstepIfDue() {
        let now = CACurrentMediaTime()
        guard footsteps.allowsStep(at: now, isWalking: true, silenced: isAudioSilenced) else {
            return
        }
        footstepVariant += 1
        let resource = footstepSurface.resource(variant: footstepVariant)
        // Hold the next step off by the length of this one. A missing audio set
        // returns nil and simply stays silent.
        guard let clip = GameSFX.play(resource, on: .walkPlayer) else { return }
        footsteps.noteStepStarted(at: now, clipDuration: clip)
    }

    /// BG:EE `Actor::IdleActions`: on its own 16-tick script pass, a standing
    /// creature has one chance in 25 of glancing around. See `IdleBehaviourClock`.
    private func advanceIdleBehaviourTick() {
        guard idleClock.advanceTickRunsScript() else { return }
        // Don't interrupt a turn the player just asked for.
        guard pendingFacing == nil else { return }
        guard IdleBehaviourClock.rollWantsHeadTurn(
            Int.random(in: 0..<IdleBehaviourClock.headTurnOdds)
        ) else { return }
        playIdleHeadTurn()
    }

    /// A glance: step one bin off the current facing and back.
    ///
    /// BG has a dedicated `IE_ANI_HEAD_TURN` stance for this. We have no authored
    /// head-turn frames, so the nearest honest thing is the gradual turn already
    /// used for standing re-facing — one 22.5° bin out and back, at the engine's
    /// own one-bin-per-tick rate. It reads as looking around rather than as a
    /// new heading, which is the point.
    private func playIdleHeadTurn() {
        let away = Bool.random()
            ? facing.stepped(toward: ActorFacing(rawValue: (facing.rawValue + 4) % 16) ?? facing)
            : facing.stepped(toward: ActorFacing(rawValue: (facing.rawValue + 12) % 16) ?? facing)
        guard away != facing else { return }
        let home = facing
        pendingFacing = away
        run(.sequence([
            .wait(forDuration: 0.9),
            .run { [weak self] in
                guard let self, self.state == .standingIdle else { return }
                self.pendingFacing = home
            }
        ]), withKey: "idleHeadTurn")
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
        // `GetNextFace` — one 22.5-degree bin per tick along the shorter arc,
        // and none at all on a tick that already spent a step.
        movable.newOrientation = pending
        movable.advanceTurn(at: currentTick)
        facing = movable.orientation
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

        let target = ActorFacing.orient(dx: dx, dy: dy)
        pendingFacing = target == facing ? nil : target
    }

    /// BG-style Stop/right-click behavior. A cancelled approach never invokes
    /// its interaction or scene-transition completion.
    func cancelMovement() {
        pendingWalk = nil
        movable.stop()
        movable.resetPathTries()
        bumpRequest = nil
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
        body.position = standingBodyPosition
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
        movable.stop()
        movable.resetPathTries()
        bumpRequest = nil
        movementCompletion = nil
        lastLocomotionUpdateTime = nil
        pendingFacing = nil
        tickClock.reset()
        needsSeatEgress = false
        state = .standingIdle
        body.position = standingBodyPosition
        body.zPosition = 0
        body.zRotation = 0
        hideLowerBody()
        foregroundArms.isHidden = true
        foregroundArms.alpha = 0
        restoreStandingContactShadow(animated: false)
        startStandingIdle()
    }

    private func beginWalking(path: Path, completion: (() -> Void)?) {
        let isCompletingSeatEgress = needsSeatEgress || body.action(forKey: "seatEgress") != nil
        syncMovablePosition()
        movable.adopt(path)
        movementCompletion = completion
        guard movable.isMoving else {
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
            body.position = standingBodyPosition
            lowerBody.position = .zero
            body.zPosition = 0
            hideLowerBody()
        }

        if let first = movable.remainingPoints.first {
            setWalkFacing(movable.currentNodeOrientation ?? facing)
            if isCompletingSeatEgress {
                needsSeatEgress = false
                // How long the first leg takes at this actor's rate, in whole
                // engine ticks — the egress animation is matched to the walk it
                // hands over to, and `DoStep` moves in ticks, not seconds.
                let ticks = movable.ticksToReach(first, walkScale: movementProfile.walkScale ?? 0)
                animateSeatEgress(
                    duration: max(
                        ActorLocomotionPacing.minimumSegmentDuration,
                        TimeInterval(ticks) * LogicTickClock.tickDuration
                    )
                )
            }
        }
    }

    private func finishWalking(completing: Bool = true) {
        movable.stop()
        bumpRequest = nil
        stopWalkAnimation()
        // Clear the hold so the next walk's first footfall is not swallowed by
        // the tail of the last one.
        footsteps.reset()
        state = .standingIdle
        startStandingIdle()
        let completion = movementCompletion
        movementCompletion = nil
        if completing { completion?() }
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
        if let firstSeated = seatedIdleFrames.first {
            body.apply(firstSeated)
        }
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
            self.hideLowerBody()
            self.state = .standingIdle
            completion()
        }
        guard standUpFrames.count == 12 else {
            body.run(
                .sequence([.fadeOut(withDuration: 0.08), finishStanding, .fadeIn(withDuration: 0.12)]),
                withKey: "standTransition"
            )
            return
        }

        let standUp = animateFrames(
            on: body,
            frames: standUpFrames,
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

        let sitDownFrames = Array(standUpFrames.reversed())
        guard sitDownFrames.count == 12 else {
            body.run(
                .sequence([.fadeOut(withDuration: 0.08), finishSitting, .fadeIn(withDuration: 0.12)]),
                withKey: "standTransition"
            )
            return
        }

        let duration = ActorLocomotionPacing.standUpSecondsPerFrame * TimeInterval(sitDownFrames.count)
        let sitDown = animateFrames(
            on: body,
            frames: sitDownFrames,
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

    #if DEBUG
    /// Deterministic art review only. The normal animation/update path is untouched.
    func seekPoseForCapture(_ request: String) {
        let parts = request.split(separator: ":")
        guard parts.count == 2, let phase = Int(parts[1]) else { return }
        let frames: [IEAvatarVisualFrame]
        switch parts[0] {
        case "stand_up": frames = standUpFrames
        case "sit_down": frames = Array(standUpFrames.reversed())
        case "seated_idle": frames = seatedIdleFrames
        default: return
        }
        guard frames.indices.contains(phase) else { return }
        // Preserve the live local offset, including any scene height-map
        // displacement already applied by the regular update path.
        body.removeAllActions()
        body.apply(frames[phase])
    }
    #endif

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
        if let seated = seatedIdleFrames.first
            ?? seatedUpperFrames.first
            ?? standingIdleFrames[seatVisualDirection.facing]?.first {
            body.apply(seated)
        }
        body.zPosition = Self.seatedUpperLocalZ
        hideLowerBody()
        body.xScale = Self.spriteScale
        body.yScale = Self.spriteScale
        body.position = upperSeat
        // NE rear view bakes hands into the body cell.
        if let arms = seatedArmFrames.first {
            foregroundArms.apply(arms)
        }
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
    }

    /// Ping-pong breath indices for an authored strip (e.g. 8 frames -> 0...7...1).
    private static func breathCycleIndices(frameCount: Int) -> [Int] {
        guard frameCount > 1 else { return Array(0..<max(1, frameCount)) }
        return Array(0..<frameCount) + Array((1..<(frameCount - 1)).reversed())
    }

    private func startSeatedIdle() {
        guard seatedIdleFrames.count > 1 else { return }
        let indices = Self.breathCycleIndices(frameCount: seatedIdleFrames.count)
        let breathCycle = indices.map { seatedIdleFrames[$0] }
        let animate = animateFrames(on: body, frames: breathCycle, timePerFrame: 0.21)
        body.run(.repeatForever(animate), withKey: "seatedIdle")
    }

    private func startStandingIdle() {
        body.removeAction(forKey: "standingIdle")
        applyStandingIdleTexture()
        if let frames = standingIdleFrames[facing], frames.count > 1 {
            // Authored 4-frame breath loop with a long neutral hold, replacing
            // the former single-frame position bob.
            let indices = Self.breathCycleIndices(frameCount: frames.count)
            let breath = animateFrames(
                on: body,
                frames: indices.map { frames[$0] },
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
    private func setWalkFacing(_ orientation: ActorFacing) {
        facing = orientation
        pendingFacing = nil
        applyWalkTexture()
    }

    private func applyWalkTexture() {
        applySpriteScale(mirrored: facing.isMirrored)
        body.zRotation = 0
        guard let frames = walkFrames[facing], !frames.isEmpty else { return }
        walkFrameIndex %= frames.count
        body.apply(frames[walkFrameIndex])
    }

    /// Exactly one authored frame per logic tick, as the engine advances a
    /// creature animation inside `DoStep`. There is deliberately no accumulator:
    /// sharing the movement tick is what keeps the cycle locked to travel.
    private func advanceWalkFrame() {
        guard let frames = walkFrames[facing], !frames.isEmpty else { return }
        walkFrameIndex = (walkFrameIndex + 1) % frames.count
        applyWalkTexture()
    }

    private func stopWalkAnimation() {
        applyStandingIdleTexture()
        body.position = standingBodyPosition
        body.zRotation = 0
    }

    private func applyStandingIdleTexture() {
        if let idleFrame = standingIdleFrames[facing]?.first {
            body.apply(idleFrame)
        }
        applySpriteScale(mirrored: facing.isMirrored)
    }
}

extension DetectiveActorNode: GroundCircleHosting {
    /// Is the drawn figure standing somewhere other than the point the circle marks?
    ///
    /// Upstream never has to ask: `Pos` and the sprite's feet are the same point.
    /// Our seated pose lifts the body onto the chair behind the desk while the
    /// actor keeps its floor position, so a circle at `Pos` would ring bare
    /// boards in front of the desk — through the seated idle, the stand-up clip,
    /// and the egress slide back down.
    ///
    /// Asked of `body.position` rather than tracked in a flag. A flag has to be
    /// cleared on every path that puts Voss back on his feet, and the ones that
    /// forget — `finishWalking` on an order with no distance left, for one —
    /// leave the circle switched off with nothing on screen to explain it. This
    /// is the displacement itself, so there is nothing to keep in sync.
    ///
    /// `visualHeightOffset` is subtracted because it is terrain lift, not
    /// displacement: the sprite rides up a slope while the feet keep the ground
    /// point, which is exactly the case the circle should still be drawn for.
    private var bodyHasLeftTheGroundPoint: Bool {
        abs(body.position.x) > 0.5
            || abs(body.position.y - visualHeightOffset) > 0.5
    }

    func applyGroundCircle(cameraScale: CGFloat, milliseconds: UInt64) {
        // `DrawCircle` centres the ellipse on `Pos`, and `Pos` is this node's
        // origin: what navigation moves, what the sprite's foot pivot registers
        // to, and what `isOverGroundCircle` hit-tests against. The circle never
        // moves within the actor, so there is nothing to position here.
        //
        // It used to track `contactShadow.position`, which is a painted blob's
        // own registration — offset up to the shoe soles, carried onto the seat
        // by `applySeatedPose`, and settled back by only *some* of the paths out
        // of the chair. Standing up without walking left it parked at the seat,
        // one body-height up: the circle that appeared around Voss's head.
        let appearance = bodyHasLeftTheGroundPoint
            ? nil
            : GroundCircleResolver.appearance(
                groundCircleState,
                colorCycleStep: IEColorCycle.step(atMilliseconds: milliseconds)
            )
        groundCircle.apply(appearance, cameraScale: cameraScale)
    }
}
