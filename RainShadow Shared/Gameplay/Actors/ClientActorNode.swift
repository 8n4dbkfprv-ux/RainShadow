import SpriteKit

@MainActor
final class ClientActorNode: SKNode, WallStencilledActor {
    private static let stripHandoffDuration: TimeInterval = 0.16

    private let contactShadow: SKSpriteNode
    private let contactShadowKind: ContactShadowKind = .npc
    private let groundCircle = GroundCircleNode()
    /// `Selectable`'s ground-circle state. Lila is an ordinary neutral, so she
    /// falls to GemRB's `default:` case and draws cyan — and at the engine's
    /// default feedback level she is circled only under the pointer.
    var groundCircleState = GroundCircleState(enmity: .neutral, isPC: false)
    private let body: IEAvatarNode
    /// Holds the outgoing departure strip during a facing handoff crossfade.
    private let bodyHandoff: IEAvatarNode
    /// Retains the validated indexed payload and its resolved-texture cache.
    private let avatarLibrary: IEAvatarFrameLibrary?
    /// Scene grade for the neutral bake (office warm / city night cool).
    private var sceneLighting: ActorSceneLighting = .officeInterior
    private var footLight: AreaLightSample?
    private let arrivalFrames: [IEAvatarVisualFrame]
    private let departureNEFrames: [IEAvatarVisualFrame]
    private let departureNWFrames: [IEAvatarVisualFrame]
    /// Wall-clock origin of the current departure walk cycle (for phase-continuous handoff).
    private var departureWalkPhaseOrigin: TimeInterval = 0

    /// The engine's `Movable`. Lila walks the same `DoStep` the detective
    /// does; only the presentation (entrance fade, authored exit strips) differs.
    private var movable = Movable(identity: "client", position: .zero, blocksSearchMap: false)
    private var currentTick = 0
    private var lastLocomotionUpdateTime: TimeInterval?
    /// See `DetectiveActorNode.movementProfile`. Also `humanoid` — BG gives every
    /// ordinary adult the same rate.
    var movementProfile: MovementProfile = .humanoid

    /// See `DetectiveActorNode` — same contract, and she walks on the same floor.
    var footstepSurface: FootstepSurface = .floorboard
    var isAudioSilenced = false
    private var footsteps = FootstepCadence()
    private var footstepVariant = 0
    private var tickClock = LogicTickClock()
    private var movementCompletion: (() -> Void)?
    private var activePath: [CGPoint] = []
    private var locomotionMode: LocomotionMode = .idle
    private var activeDepartureBin: ClientDepartureFacing?
    private var entranceFadeRemaining: TimeInterval = 0
    private var exitFadeRemaining: TimeInterval = 0
    private let lookAheadDistance: CGFloat = 48
    /// Full-canvas atlas fallback pivot; indexed frames carry their cropped pivot.
    private static let compatibilityAnchor = CGPoint(x: 0.5, y: 39 / 256)

    private enum LocomotionMode {
        case idle
        case entrance
        case exit
        case bumped
    }

    var isLocomoting: Bool { movable.isMoving || locomotionMode != .idle }

    /// Conversation owner id for talk counting (IE `NumTimesTalkedTo`), and the graph a
    /// click on this actor opens. Both `nil` means "not talkable" — the scene skips it.
    ///
    /// NPC *facing* on approach is art-blocked, not code-blocked: this atlas is an
    /// arrival idle plus two `ClientDepartureFacing` bins, so there is no frame for
    /// "turns to look at you". The PC turns; the NPC does not. Do not fake it by reusing
    /// a departure frame as an idle.
    var dialogueOwnerID: String?
    var dialogueGraphID: String?

    /// Hit area for a talk click, in the parent's coordinate space.
    var interactionFrame: CGRect {
        calculateAccumulatedFrame()
    }

    override init() {
        let __traceStart = AreaLoadTrace.isEchoing ? CFAbsoluteTimeGetCurrent() : 0
        defer { AreaLoadTrace.note("init.ClientActorNode", milliseconds: (CFAbsoluteTimeGetCurrent() - __traceStart) * 1_000) }
        let indexedLibrary = try? IEAvatarFrameLibrary.shared(character: "Lila")
        avatarLibrary = indexedLibrary
        // 8 authored walk phases + a final standing idle frame (index 08).
        arrivalFrames = Self.loadFrames(
            library: indexedLibrary,
            prefix: "lila_arrival_sw",
            count: ActorLocomotionPacing.walkFramesPerCycle + 1
        )
        departureNEFrames = Self.loadFrames(
            library: indexedLibrary,
            prefix: "lila_departure_ne",
            count: ActorLocomotionPacing.walkFramesPerCycle
        )
        departureNWFrames = Self.loadFrames(
            library: indexedLibrary,
            prefix: "lila_departure_nw",
            count: ActorLocomotionPacing.walkFramesPerCycle
        )

        contactShadow = ContactShadowFactory.make(kind: contactShadowKind)

        body = IEAvatarNode(frame: arrivalFrames.last)
        if arrivalFrames.last == nil {
            body.color = SKColor(red: 0.18, green: 0.08, blue: 0.1, alpha: 1)
            body.size = CGSize(width: 42, height: OfficeInteriorScale.clientBodyHeight)
            body.anchorPoint = Self.compatibilityAnchor
        }
        // Same adult standing presentation as DetectiveActorNode (integer-pixel sprite scale).
        // Never negate xScale — handbag/light contract forbids whole-figure mirroring.
        body.xScale = OfficeInteriorScale.ActorDisplay.spriteScale
        body.yScale = OfficeInteriorScale.ActorDisplay.spriteScale

        bodyHandoff = IEAvatarNode(frame: nil)
        bodyHandoff.xScale = body.xScale
        bodyHandoff.yScale = body.yScale
        bodyHandoff.isHidden = true
        bodyHandoff.alpha = 0
        bodyHandoff.zPosition = body.zPosition - 0.1

        super.init()
        name = "client.lilaMarch"
        addChild(contactShadow)
        addChild(groundCircle)
        addChild(bodyHandoff)
        addChild(body)
        applySceneLighting(.officeInterior)
        isHidden = true
    }

    private static func loadFrames(
        library: IEAvatarFrameLibrary?,
        prefix: String,
        count: Int
    ) -> [IEAvatarVisualFrame] {
        let stems = (0..<count).map { String(format: "%@_%02d", prefix, $0) }
        return IEAvatarFrames.sequence(
            library: library,
            atlas: "LilaArrival.atlas",
            stems: stems,
            compatibilityAnchor: compatibilityAnchor
        ) ?? []
    }

    private func animateFrames(
        _ frames: [IEAvatarVisualFrame],
        timePerFrame: TimeInterval
    ) -> SKAction {
        .sequence(frames.map { frame in
            .sequence([
                .run { [weak self] in self?.body.apply(frame) },
                .wait(forDuration: timePerFrame)
            ])
        })
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("ClientActorNode is created programmatically")
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
    func applySceneLighting(_ lighting: ActorSceneLighting) {
        sceneLighting = lighting
        applyBodyTint()
    }

    func applyFootLight(_ sample: AreaLightSample) {
        footLight = sample
        applyBodyTint()
    }


    private var tintedLayers: [IEAvatarNode] { [body, bodyHandoff] }

    /// `Map::DrawMap`'s per-actor tint. See
    /// ``DetectiveActorNode/applyBodyTint()`` for the quoted upstream and for
    /// why the `colorBlendFactor` lerp this replaces was the wrong operation.
    private func applyBodyTint() {
        var flags: IEBlitFlags = .blended
        var tint = IEColor.opaqueWhite
        if let footLight {
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
            layer.colorBlendFactor = 0
        }
        contactShadow.alpha = contactShadowKind.standingAlpha * sceneLighting.contactShadowAlphaScale
    }

    /// Hand the engine this actor's position, snapped to whole units — see
    /// `DetectiveActorNode.syncMovablePosition`. `Movable`'s step arithmetic is
    /// integral and arrival is an exact equality, so a SpriteKit node's
    /// sub-unit remainder must not reach it.
    private func syncMovablePosition(_ point: CGPoint? = nil) {
        movable.position = (point ?? position).rounded
    }

    /// Hand this actor its area — see `DetectiveActorNode.attachNavigation`.
    func attachNavigation(_ map: NavigationMap, id: String) {
        movable.map = map
        movable.identity = id
        movable.circleSize = ActorLocomotionPacing.personalSpaceCells
        syncMovablePosition()
    }

    /// `Movable::BumpAway` — step off the spot so a mover can get past, and
    /// remember where to come back to. `DoStep` walks it back on its own once
    /// the spot frees up.
    func bumpAway() {
        syncMovablePosition()
        movable.bumpAway()
        position = movable.position
    }

    /// Pump the bump-back half of `DoStep` while standing idle. A bumped actor
    /// that is not walking still needs its tick, or it never reclaims its spot.
    func advanceBumpRecovery() {
        guard movable.isBumped, !movable.isMoving else { return }
        currentTick += 1
        syncMovablePosition()
        movable.doStep(walkScale: movementProfile.walkScale ?? 0, time: currentTick)
        position = movable.position
    }

    var isBumped: Bool { movable.isBumped }

    /// BG:EE-style walk used for scripted moves.
    func walk(path: [CGPoint], completion: (() -> Void)? = nil) {
        guard let start = path.first else {
            completion?()
            return
        }
        removeAllActions()
        body.removeAllActions()
        clearDepartureHandoff()
        body.position = .zero
        body.alpha = 1
        if isHidden {
            position = start
            isHidden = false
            alpha = 1
        }
        locomotionMode = .bumped
        activePath = path
        movementCompletion = completion
        lastLocomotionUpdateTime = nil
        tickClock.reset()
        syncMovablePosition()
        movable.adopt(Path(points: Array(path.dropFirst()), from: position))
        startArrivalWalkCycle()
        if !movable.isMoving {
            finishLocomotion()
        }
    }

    func performEntrance(along points: [CGPoint], completion: @escaping () -> Void) {
        guard let start = points.first else {
            completion()
            return
        }

        removeAllActions()
        body.removeAllActions()
        bodyHandoff.removeAllActions()
        clearDepartureHandoff()
        body.position = .zero
        bodyHandoff.position = .zero
        body.alpha = 1
        position = start
        alpha = 0
        isHidden = false
        entranceFadeRemaining = 0.22
        exitFadeRemaining = 0
        locomotionMode = .entrance
        activePath = points
        activeDepartureBin = nil
        movementCompletion = completion
        lastLocomotionUpdateTime = nil
        tickClock.reset()
        syncMovablePosition(start)
        movable.adopt(Path(points: Array(points.dropFirst()), from: start))
        startArrivalWalkCycle()
        if !movable.isMoving {
            alpha = 1
            finishLocomotion()
        }
    }

    /// Wall-clock seek for QA captures when the SKView may not advance actions
    /// (no drawable / background launch). Mirrors `performEntrance` timing.
    func seekEntrance(along points: [CGPoint], elapsed: TimeInterval) {
        guard let start = points.first else { return }
        removeAllActions()
        body.removeAllActions()
        clearDepartureHandoff()
        body.position = .zero
        body.alpha = 1
        isHidden = false
        alpha = 1
        locomotionMode = .idle
        movable.stop()

        var prior = start
        var t = elapsed
        // Match fade-in occupying the first 0.22s of the entrance sequence.
        t -= 0.22
        if t <= 0 {
            position = start
            return
        }
        for destination in points.dropFirst() {
            let distance = hypot(destination.x - prior.x, destination.y - prior.y)
            guard distance > 0.25 else {
                prior = destination
                continue
            }
            // The engine walks in whole ticks, so a leg's duration is the tick
            // count `NormalizeDeltas` actually produces, not distance / speed.
            var probe = movable
            probe.position = prior
            let ticks = probe.ticksToReach(destination, walkScale: movementProfile.walkScale ?? 0)
            let duration = max(
                ActorLocomotionPacing.minimumSegmentDuration,
                TimeInterval(ticks) * LogicTickClock.tickDuration
            )
            if t <= duration {
                let u = CGFloat(t / duration)
                position = CGPoint(
                    x: prior.x + (destination.x - prior.x) * u,
                    y: prior.y + (destination.y - prior.y) * u
                )
                let walkingFrames = Array(arrivalFrames.prefix(ActorLocomotionPacing.walkFramesPerCycle))
                if let frame = walkingFrames.first {
                    body.apply(frame)
                }
                return
            }
            t -= duration
            prior = destination
        }
        position = prior
        if let idle = arrivalFrames.last {
            body.apply(idle)
        }
        startIdle()
    }

    func performExit(along points: [CGPoint], completion: @escaping () -> Void) {
        guard let start = points.first else {
            completion()
            return
        }

        removeAllActions()
        body.removeAllActions()
        bodyHandoff.removeAllActions()
        clearDepartureHandoff()
        body.position = .zero
        bodyHandoff.position = .zero
        body.alpha = 1
        position = start
        alpha = 1
        entranceFadeRemaining = 0
        exitFadeRemaining = 0
        locomotionMode = .exit
        activePath = points
        activeDepartureBin = nil
        movementCompletion = completion
        lastLocomotionUpdateTime = nil
        tickClock.reset()
        syncMovablePosition(start)
        movable.adopt(Path(points: Array(points.dropFirst()), from: start))

        let expected = ActorLocomotionPacing.walkFramesPerCycle
        if departureNEFrames.count != expected {
            assertionFailure("Expected \(expected) NE departure frames, found \(departureNEFrames.count)")
        }
        if departureNWFrames.count != expected {
            assertionFailure("Expected \(expected) NW departure frames, found \(departureNWFrames.count)")
        }

        updateDepartureFacing(fromIndex: 0)
        if !movable.isMoving {
            finishLocomotion()
        }
    }

    /// Skip-safe snap to the authored entrance end state, then fires the same
    /// completion as a natural path finish (idle pose at last path point).
    func completeEntranceImmediately() {
        guard locomotionMode == .entrance || movementCompletion != nil else { return }
        // Prefer the live route path; fall back if already clearing.
        let end = activePath.last ?? position
        removeAllActions()
        body.removeAllActions()
        bodyHandoff.removeAllActions()
        clearDepartureHandoff()
        body.position = .zero
        body.alpha = 1
        entranceFadeRemaining = 0
        exitFadeRemaining = 0
        position = end
        alpha = 1
        isHidden = false
        locomotionMode = .entrance
        finishLocomotion()
    }

    /// Skip-safe snap to the authored exit end state (hidden past the door),
    /// then fires the same completion as a natural exit finish.
    func completeExitImmediately() {
        let end = activePath.last ?? position
        removeAllActions()
        body.removeAllActions()
        bodyHandoff.removeAllActions()
        clearDepartureHandoff()
        body.position = .zero
        body.alpha = 1
        entranceFadeRemaining = 0
        exitFadeRemaining = 0
        position = end
        // Natural exit ends faded out and hidden.
        isHidden = true
        alpha = 1
        locomotionMode = .exit
        finishLocomotion()
    }

    /// Advances RouteFollower locomotion from the scene clock (BG P-regulator).
    /// Drops the partial tick when the world resumes.
    ///
    /// `LogicTickClock` keeps a sub-tick remainder on purpose so a 60 Hz render
    /// loop does not lose steps. Across a pause that remainder is stale, and
    /// spending it would move the actor on the frame the player unfreezes.
    func resetLocomotionClock() {
        tickClock.reset()
    }

    func updateLocomotion(at currentTime: TimeInterval, worldIsPaused: Bool) {
        defer { lastLocomotionUpdateTime = currentTime }
        guard !worldIsPaused, locomotionMode != .idle else { return }

        let previousTime = lastLocomotionUpdateTime
        let deltaTime: TimeInterval
        if let previousTime {
            deltaTime = min(
                max(0, currentTime - previousTime),
                ActorLocomotionPacing.maximumFrameDelta
            )
        } else {
            // First tick after a route is armed — spend no movement yet.
            return
        }
        guard deltaTime > 0 else { return }

        if entranceFadeRemaining > 0 {
            entranceFadeRemaining = max(0, entranceFadeRemaining - deltaTime)
            alpha = max(0, min(1, 1 - CGFloat(entranceFadeRemaining / 0.22)))
        }

        if exitFadeRemaining > 0 {
            exitFadeRemaining = max(0, exitFadeRemaining - deltaTime)
            alpha = max(0, min(1, CGFloat(exitFadeRemaining / 0.2)))
            if exitFadeRemaining <= 0 {
                finishExitFade()
            }
            return
        }

        guard movable.isMoving else {
            if locomotionMode == .exit {
                beginExitFade()
            } else {
                finishLocomotion()
            }
            return
        }

        // Root motion runs on the engine's fixed logic tick; the fades above stay
        // on wall-clock delta because they are presentation, not locomotion.
        for _ in 0..<tickClock.drain(deltaTime: deltaTime) {
            currentTick += 1
            syncMovablePosition()
            let outcome = movable.doStep(
                walkScale: movementProfile.walkScale ?? 0,
                time: currentTick
            )
            position = movable.position
            if outcome.moved {
                playFootstepIfDue()
            }

            if locomotionMode == .exit {
                let fromIndex = max(0, activePath.count - movable.remainingPoints.count - 1)
                updateDepartureFacing(fromIndex: fromIndex)
            }

            if outcome.arrived || outcome.abandoned {
                if locomotionMode == .exit {
                    beginExitFade()
                } else {
                    finishLocomotion()
                }
                return
            }
        }
    }

    // MARK: - Private

    private func startArrivalWalkCycle() {
        let walkingFrames = Array(arrivalFrames.prefix(ActorLocomotionPacing.walkFramesPerCycle))
        guard walkingFrames.count == ActorLocomotionPacing.walkFramesPerCycle else { return }
        body.removeAction(forKey: "clientWalkCycle")
        body.run(
            .repeatForever(animateFrames(
                walkingFrames,
                timePerFrame: ActorLocomotionPacing.walkCycleSecondsPerFrame
            )),
            withKey: "clientWalkCycle"
        )
    }

    private func updateDepartureFacing(fromIndex: Int) {
        let look = ClientDepartureFacing.lookAheadVector(
            along: activePath,
            fromIndex: max(0, min(fromIndex, max(0, activePath.count - 2))),
            minimumDistance: lookAheadDistance
        )
        let bin = ClientDepartureFacing.bin(dx: look.dx, dy: look.dy)
        if activeDepartureBin != bin {
            let crossfade = activeDepartureBin != nil
            startDepartureWalkCycle(departureFrames(for: bin), crossfade: crossfade)
            activeDepartureBin = bin
        } else if activeDepartureBin == nil {
            startDepartureWalkCycle(departureFrames(for: .northEast), crossfade: false)
            activeDepartureBin = .northEast
        }
    }

    private func beginExitFade() {
        body.removeAction(forKey: "clientWalkCycle")
        clearDepartureHandoff()
        exitFadeRemaining = 0.2
    }

    private func finishExitFade() {
        isHidden = true
        alpha = 1
        finishLocomotion()
    }

    /// BG:EE `Actor::PlayWalkSound`, on the non-party channel. See
    /// `FootstepCadence` for why this is gated on clip length.
    private func playFootstepIfDue() {
        let now = CACurrentMediaTime()
        guard footsteps.allowsStep(at: now, isWalking: true, silenced: isAudioSilenced) else {
            return
        }
        footstepVariant += 1
        guard let clip = GameSFX.play(
            footstepSurface.resource(variant: footstepVariant),
            on: .walkOther
        ) else { return }
        footsteps.noteStepStarted(at: now, clipDuration: clip)
    }

    private func finishLocomotion() {
        footsteps.reset()
        let completion = movementCompletion
        movementCompletion = nil
        movable.stop()
        let mode = locomotionMode
        locomotionMode = .idle
        activePath = []
        body.removeAction(forKey: "clientWalkCycle")
        clearDepartureHandoff()

        switch mode {
        case .entrance, .bumped:
            if let idle = arrivalFrames.last {
                body.apply(idle)
            }
            startIdle()
        case .exit:
            break
        case .idle:
            break
        }
        completion?()
    }

    private func departureFrames(for bin: ClientDepartureFacing) -> [IEAvatarVisualFrame] {
        let expected = ActorLocomotionPacing.walkFramesPerCycle
        switch bin {
        case .northWest:
            if departureNWFrames.count == expected { return departureNWFrames }
            if departureNEFrames.count == expected { return departureNEFrames }
        case .northEast:
            if departureNEFrames.count == expected { return departureNEFrames }
            if departureNWFrames.count == expected { return departureNWFrames }
        }
        return departureNEFrames.isEmpty ? departureNWFrames : departureNEFrames
    }

    private func startDepartureWalkCycle(_ frames: [IEAvatarVisualFrame], crossfade: Bool) {
        guard frames.count == ActorLocomotionPacing.walkFramesPerCycle else { return }

        // Keep stride phase across the NW→NE door handoff so the turn does not
        // hard-restart mid-step (reads as haywire gait even with correct facing).
        let frameDuration = ActorLocomotionPacing.walkCycleSecondsPerFrame
        let phase: Int
        if crossfade, departureWalkPhaseOrigin > 0 {
            let elapsed = Date.timeIntervalSinceReferenceDate - departureWalkPhaseOrigin
            phase = Int(elapsed / frameDuration) % frames.count
        } else {
            phase = 0
            departureWalkPhaseOrigin = Date.timeIntervalSinceReferenceDate
        }
        let ordered = ClientDepartureFacing.texturesStartingAtPhase(frames, phase: phase)

        if crossfade, let outgoing = body.currentFrame {
            bodyHandoff.removeAllActions()
            bodyHandoff.apply(outgoing)
            bodyHandoff.xScale = abs(OfficeInteriorScale.ActorDisplay.spriteScale)
            bodyHandoff.yScale = OfficeInteriorScale.ActorDisplay.spriteScale
            bodyHandoff.position = body.position
            bodyHandoff.isHidden = false
            bodyHandoff.alpha = 1
            body.alpha = 0
            bodyHandoff.run(.sequence([
                .fadeOut(withDuration: Self.stripHandoffDuration),
                .run { [weak self] in self?.clearDepartureHandoff() }
            ]))
            body.run(.fadeIn(withDuration: Self.stripHandoffDuration))
        } else {
            clearDepartureHandoff()
            body.alpha = 1
        }

        body.removeAction(forKey: "clientWalkCycle")
        body.apply(ordered[0])
        body.xScale = abs(OfficeInteriorScale.ActorDisplay.spriteScale)
        body.run(
            .repeatForever(animateFrames(ordered, timePerFrame: frameDuration)),
            withKey: "clientWalkCycle"
        )
    }

    private func clearDepartureHandoff() {
        bodyHandoff.removeAllActions()
        bodyHandoff.alpha = 0
        bodyHandoff.clear()
    }

    private func startIdle() {
        body.removeAction(forKey: "clientIdle")
        body.run(
            .repeatForever(.sequence([
                .moveBy(x: 0, y: 1, duration: 0.85),
                .moveBy(x: 0, y: -1, duration: 0.9)
            ])),
            withKey: "clientIdle"
        )
    }
}

extension ClientActorNode: GroundCircleHosting {
    func applyGroundCircle(cameraScale: CGFloat, milliseconds: UInt64) {
        // Centred on the node origin — `Pos` — as the detective's is. Lila never
        // sits, so nothing ever displaces her body from it and she needs none of
        // the seated suppression either.
        groundCircle.apply(
            GroundCircleResolver.appearance(
                groundCircleState,
                colorCycleStep: IEColorCycle.step(atMilliseconds: milliseconds)
            ),
            cameraScale: cameraScale
        )
    }
}
