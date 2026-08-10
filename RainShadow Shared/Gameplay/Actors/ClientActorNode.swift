import SpriteKit

@MainActor
final class ClientActorNode: SKNode {
    private static let stripHandoffDuration: TimeInterval = 0.16

    private let contactShadow: SKSpriteNode
    private let contactShadowKind: ContactShadowKind = .npc
    private let selectionRing: SKSpriteNode
    private let body: SKSpriteNode
    /// Holds the outgoing departure strip during a facing handoff crossfade.
    private let bodyHandoff: SKSpriteNode
    /// Scene grade for the neutral bake (office warm / city night cool).
    private var sceneLighting: ActorSceneLighting = .officeInterior
    private let arrivalTextures: [SKTexture]
    private let departureNETextures: [SKTexture]
    private let departureNWTextures: [SKTexture]
    /// Wall-clock origin of the current departure walk cycle (for phase-continuous handoff).
    private var departureWalkPhaseOrigin: TimeInterval = 0

    private var routeFollower = RouteFollower()
    private var lastLocomotionUpdateTime: TimeInterval?
    /// See `DetectiveActorNode.movementProfile`. Also `humanoid` — BG gives every
    /// ordinary adult the same rate.
    var movementProfile: MovementProfile = .humanoid
    private var tickClock = LogicTickClock()
    private var movementCompletion: (() -> Void)?
    private var activePath: [CGPoint] = []
    private var locomotionMode: LocomotionMode = .idle
    private var activeDepartureBin: ClientDepartureFacing?
    private var entranceFadeRemaining: TimeInterval = 0
    private var exitFadeRemaining: TimeInterval = 0
    private let lookAheadDistance: CGFloat = 48

    private enum LocomotionMode {
        case idle
        case entrance
        case exit
        case bumped
    }

    var isLocomoting: Bool { routeFollower.isMoving || locomotionMode != .idle }

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
        // 8 authored walk phases + a final standing idle frame (index 08).
        arrivalTextures = (0..<(ActorLocomotionPacing.walkFramesPerCycle + 1)).compactMap {
            GameArt.texture(named: String(format: "lila_arrival_sw_%02d", $0))
        }
        departureNETextures = (0..<ActorLocomotionPacing.walkFramesPerCycle).compactMap {
            GameArt.texture(named: String(format: "lila_departure_ne_%02d", $0))
        }
        departureNWTextures = (0..<ActorLocomotionPacing.walkFramesPerCycle).compactMap {
            GameArt.texture(named: String(format: "lila_departure_nw_%02d", $0))
        }

        contactShadow = ContactShadowFactory.make(kind: contactShadowKind)

        selectionRing = SelectionRingFactory.make(
            kind: .npc,
            displaySize: contactShadowKind.displaySize,
            position: contactShadowKind.footPosition,
            scale: OfficeInteriorScale.ActorDisplay.standingScale
        )

        if let texture = arrivalTextures.last {
            body = SKSpriteNode(texture: texture, size: OfficeInteriorScale.ActorDisplay.spriteDisplaySize)
        } else {
            body = SKSpriteNode(
                color: SKColor(red: 0.18, green: 0.08, blue: 0.1, alpha: 1),
                size: CGSize(width: 42, height: OfficeInteriorScale.clientBodyHeight)
            )
        }
        body.anchorPoint = CGPoint(x: 0.5, y: 39 / 256)
        body.texture?.filteringMode = .nearest
        // Same adult standing presentation as DetectiveActorNode (integer-pixel sprite scale).
        // Never negate xScale — handbag/light contract forbids whole-figure mirroring.
        body.xScale = OfficeInteriorScale.ActorDisplay.spriteScale
        body.yScale = OfficeInteriorScale.ActorDisplay.spriteScale

        bodyHandoff = SKSpriteNode(color: .clear, size: OfficeInteriorScale.ActorDisplay.spriteDisplaySize)
        bodyHandoff.anchorPoint = body.anchorPoint
        bodyHandoff.xScale = body.xScale
        bodyHandoff.yScale = body.yScale
        bodyHandoff.isHidden = true
        bodyHandoff.alpha = 0
        bodyHandoff.zPosition = body.zPosition - 0.1

        super.init()
        name = "client.lilaMarch"
        addChild(contactShadow)
        addChild(selectionRing)
        addChild(bodyHandoff)
        addChild(body)
        applySceneLighting(.officeInterior)
        isHidden = true
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("ClientActorNode is created programmatically")
    }

    /// Pull the neutral-baked body into the current scene’s value/colour grade.
    func applySceneLighting(_ lighting: ActorSceneLighting) {
        sceneLighting = lighting
        for layer in [body, bodyHandoff] {
            layer.color = lighting.bodyTint
            layer.colorBlendFactor = lighting.bodyBlend
        }
        selectionRing.alpha = lighting.selectionRingAlpha
        contactShadow.alpha = contactShadowKind.standingAlpha * lighting.contactShadowAlphaScale
    }

    /// BG:EE-style RouteFollower walk used for bump sidesteps and scripted moves.
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
        routeFollower.replaceRoute(with: Array(path.dropFirst()), from: position)
        startArrivalWalkCycle()
        if !routeFollower.isMoving {
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
        routeFollower.replaceRoute(with: Array(points.dropFirst()), from: start)
        startArrivalWalkCycle()
        if !routeFollower.isMoving {
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
        routeFollower.cancel()

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
            let duration = movementProfile.pathDuration(distance: distance)
            if t <= duration {
                let u = CGFloat(t / duration)
                position = CGPoint(
                    x: prior.x + (destination.x - prior.x) * u,
                    y: prior.y + (destination.y - prior.y) * u
                )
                let walkingFrames = Array(arrivalTextures.prefix(ActorLocomotionPacing.walkFramesPerCycle))
                if let frame = walkingFrames.first {
                    body.texture = frame
                    body.texture?.filteringMode = .nearest
                }
                return
            }
            t -= duration
            prior = destination
        }
        position = prior
        if let idle = arrivalTextures.last {
            body.texture = idle
            body.texture?.filteringMode = .nearest
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
        routeFollower.replaceRoute(with: Array(points.dropFirst()), from: start)

        let expected = ActorLocomotionPacing.walkFramesPerCycle
        if departureNETextures.count != expected {
            assertionFailure("Expected \(expected) NE departure textures, found \(departureNETextures.count)")
        }
        if departureNWTextures.count != expected {
            assertionFailure("Expected \(expected) NW departure textures, found \(departureNWTextures.count)")
        }

        updateDepartureFacing(fromIndex: 0)
        if !routeFollower.isMoving {
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

        guard routeFollower.isMoving else {
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
            let step = routeFollower.advance(
                from: position,
                deltaTime: LogicTickClock.tickDuration,
                speed: movementProfile.walkSpeed
            )
            position = step.position

            if locomotionMode == .exit {
                let fromIndex = max(0, activePath.count - routeFollower.waypoints.count - 1)
                updateDepartureFacing(fromIndex: fromIndex)
            }

            if step.didArrive {
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
        let walkingFrames = Array(arrivalTextures.prefix(ActorLocomotionPacing.walkFramesPerCycle))
        guard walkingFrames.count == ActorLocomotionPacing.walkFramesPerCycle else { return }
        walkingFrames.forEach { $0.filteringMode = .nearest }
        body.removeAction(forKey: "clientWalkCycle")
        body.run(
            .repeatForever(.animate(
                with: walkingFrames,
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
            startDepartureWalkCycle(departureTextures(for: bin), crossfade: crossfade)
            activeDepartureBin = bin
        } else if activeDepartureBin == nil {
            startDepartureWalkCycle(departureTextures(for: .northEast), crossfade: false)
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

    private func finishLocomotion() {
        let completion = movementCompletion
        movementCompletion = nil
        routeFollower.cancel()
        let mode = locomotionMode
        locomotionMode = .idle
        activePath = []
        body.removeAction(forKey: "clientWalkCycle")
        clearDepartureHandoff()

        switch mode {
        case .entrance, .bumped:
            if let idle = arrivalTextures.last {
                body.texture = idle
                body.texture?.filteringMode = .nearest
            }
            startIdle()
        case .exit:
            break
        case .idle:
            break
        }
        completion?()
    }

    private func departureTextures(for bin: ClientDepartureFacing) -> [SKTexture] {
        let expected = ActorLocomotionPacing.walkFramesPerCycle
        switch bin {
        case .northWest:
            if departureNWTextures.count == expected { return departureNWTextures }
            if departureNETextures.count == expected { return departureNETextures }
        case .northEast:
            if departureNETextures.count == expected { return departureNETextures }
            if departureNWTextures.count == expected { return departureNWTextures }
        }
        return departureNETextures.isEmpty ? departureNWTextures : departureNETextures
    }

    private func startDepartureWalkCycle(_ textures: [SKTexture], crossfade: Bool) {
        guard textures.count == ActorLocomotionPacing.walkFramesPerCycle else { return }
        textures.forEach { $0.filteringMode = .nearest }

        // Keep stride phase across the NW→NE door handoff so the turn does not
        // hard-restart mid-step (reads as haywire gait even with correct facing).
        let frameDuration = ActorLocomotionPacing.walkCycleSecondsPerFrame
        let phase: Int
        if crossfade, departureWalkPhaseOrigin > 0 {
            let elapsed = Date.timeIntervalSinceReferenceDate - departureWalkPhaseOrigin
            phase = Int(elapsed / frameDuration) % textures.count
        } else {
            phase = 0
            departureWalkPhaseOrigin = Date.timeIntervalSinceReferenceDate
        }
        let ordered = ClientDepartureFacing.texturesStartingAtPhase(textures, phase: phase)

        if crossfade, let outgoing = body.texture {
            bodyHandoff.removeAllActions()
            bodyHandoff.texture = outgoing
            bodyHandoff.texture?.filteringMode = .nearest
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
        body.texture = ordered[0]
        body.texture?.filteringMode = .nearest
        body.xScale = abs(OfficeInteriorScale.ActorDisplay.spriteScale)
        body.run(
            .repeatForever(.animate(
                with: ordered,
                timePerFrame: frameDuration
            )),
            withKey: "clientWalkCycle"
        )
    }

    private func clearDepartureHandoff() {
        bodyHandoff.removeAllActions()
        bodyHandoff.isHidden = true
        bodyHandoff.alpha = 0
        bodyHandoff.texture = nil
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
