import SpriteKit

/// The world a cutscene acts on. Scenes implement only what they actually own —
/// the opening exterior has no actors, no doors, and no dialogue, and says so by
/// taking the defaults.
@MainActor
protocol CutsceneStage: AnyObject {
    /// The node that can be driven for a cue's subject, if this scene has one.
    func cutsceneActor(_ id: CutsceneActorID) -> CutsceneActorDriving?
    /// Door leaf plus its search-map cells. BG:EE clears the cells before a
    /// creature paths through the opening.
    func cutsceneSetDoor(_ door: CutsceneDoorID, open: Bool, reason: CutsceneCompletionReason)
    /// `SetGlobal` — the guard flag that stops a cutscene re-firing.
    func cutsceneSetFlag(_ flag: String)
    /// `StartCutSceneMode` / `EndCutSceneMode`: free-play rails and player input.
    func cutsceneSetMode(_ active: Bool, reason: CutsceneCompletionReason)
    /// Hide the dialogue panel without moving the graph.
    func cutsceneSuppressDialogue()
    /// Reopen it, advancing the deferred session to `nodeID`.
    func cutsceneResumeDialogue(nodeID: String?)
    func cutscenePlayVoiceOver(_ assetName: String)
    /// Resolve an authored string key for overhead text.
    func cutsceneText(forKey key: String) -> String?
    /// The one terminal notification. Fires once, whether the cutscene played
    /// out or the player broke it.
    func cutsceneDidComplete(id: String, reason: CutsceneCompletionReason)
}

extension CutsceneStage {
    func cutsceneActor(_ id: CutsceneActorID) -> CutsceneActorDriving? { nil }
    func cutsceneSetDoor(_ door: CutsceneDoorID, open: Bool, reason: CutsceneCompletionReason) {}
    func cutsceneSetFlag(_ flag: String) {}
    func cutsceneSetMode(_ active: Bool, reason: CutsceneCompletionReason) {}
    func cutsceneSuppressDialogue() {}
    func cutsceneResumeDialogue(nodeID: String?) {}
    func cutscenePlayVoiceOver(_ assetName: String) {}
    func cutsceneText(forKey key: String) -> String? { nil }
}

/// What a cutscene can ask of an actor. Adapters on `DetectiveActorNode` and
/// `ClientActorNode` keep locomotion where it already lives — every floor move
/// still runs through `RouteFollower`, never an `SKAction` chain.
@MainActor
protocol CutsceneActorDriving: AnyObject {
    var cutsceneWorldPosition: CGPoint { get }
    /// `MoveToPoint` / authored polyline. Blocks until arrival. `style` carries
    /// the threshold presentation so a skip can land on the same end state.
    func cutsceneFollow(path: [CGPoint], style: CutsceneWalkStyle, completion: @escaping () -> Void)
    /// `JumpToPoint` — teleport, and land in the pose the walk would have left.
    func cutsceneJump(to point: CGPoint, style: CutsceneWalkStyle)
    /// `Face(dir)`.
    func cutsceneFace(_ facing: ActorFacing)
    /// `FaceObject` — the slow BG pivot toward a world point.
    func cutsceneFace(toward point: CGPoint)
    /// Rise from a seat. Blocks until the stand-up strip finishes.
    func cutsceneStandUp(completion: @escaping () -> Void)
}

/// Plays a `Cutscene` against a SpriteKit scene.
///
/// The `CutsceneRunner` half decides *what* happens and when; this half makes it
/// visible. Same division as `DialogueSession` and `DialoguePresenter`, and for
/// the same payoff — the timing of every shipped cutscene is unit-tested without
/// a render loop.
@MainActor
final class CutsceneDirector {

    private(set) var runner = CutsceneRunner()
    private unowned let scene: BaseGameScene
    private weak var stage: CutsceneStage?

    private var clock = LogicTickClock()
    private var lastUpdateTime: TimeInterval?
    private(set) var activeCutsceneID: String?
    /// Latched for the terminal apply so chrome can cut rather than ease.
    private var completionReason: CutsceneCompletionReason = .natural

    // Camera rail.
    private(set) var ownsCamera = false
    private var cameraTarget: CGPoint?
    private var cameraFollowActor: CutsceneActorID?
    private var cameraSpeed: ScrollSpeed = .instant
    /// Multiple of the scene's resolved base zoom. Absolute scales do not survive
    /// `layoutViewport()`, which re-applies `baseCameraScale` on every resize.
    private(set) var cameraScaleMultiplier: CGFloat = 1
    private var cameraScaleFrom: CGFloat = 1
    private var cameraScaleTo: CGFloat = 1
    private var cameraScaleElapsed: TimeInterval = 0
    private var cameraScaleDuration: TimeInterval = 0

    // Fade rail. Interpolated here rather than by an `SKAction` so chrome runs on
    // the cutscene's clock, not a second one.
    private var fadeColor: CutsceneColor = .black
    private var fadeFrom: CGFloat = 0
    private var fadeTo: CGFloat = 0
    private var fadeElapsed: TimeInterval = 0
    private var fadeDuration: TimeInterval = 0

    // Chrome, all parented to `cinematicRoot`.
    private lazy var letterbox = CutsceneLetterboxNode()
    private lazy var fadeOverlay = CutsceneFadeNode()
    private var overheadText: OverheadTextNode?

    init(scene: BaseGameScene) {
        self.scene = scene
    }

    var isPlaying: Bool { runner.isPlaying }

    // MARK: - Lifecycle

    func play(_ cutscene: Cutscene, on stage: CutsceneStage) {
        self.stage = stage
        activeCutsceneID = cutscene.id
        completionReason = .natural
        clock.reset()
        lastUpdateTime = nil
        installChromeIfNeeded()
        apply(runner.begin(cutscene, at: ProcessInfo.processInfo.systemUptime))
    }

    /// BG:EE ESC. Returns true when a running cutscene claimed the input, so the
    /// caller knows not to also close an overlay or cancel a move order.
    @discardableResult
    func trySkip() -> Bool {
        guard runner.canSkip(at: ProcessInfo.processInfo.systemUptime) else { return false }
        completionReason = .skipped
        apply(runner.skip(at: ProcessInfo.processInfo.systemUptime))
        return true
    }

    /// Drives the timeline. Called from the scene's `update(_:)`.
    func update(_ currentTime: TimeInterval) {
        // The frame delta is computed before the playing guard on purpose. A
        // camera push can outlive the cutscene that started it — the opening's
        // final scale lands after the last chrome beat — and a clock that only
        // ticked while the runner was playing would hand that tail a stale
        // `lastUpdateTime` and run it at the clamp every frame.
        let delta = lastUpdateTime.map {
            min(max(0, currentTime - $0), ActorLocomotionPacing.maximumFrameDelta)
        } ?? 0
        lastUpdateTime = currentTime
        advanceRails(delta)
        guard runner.isPlaying else { return }
        let ticks = clock.drain(deltaTime: delta)
        guard ticks > 0 else { return }
        apply(runner.advance(ticks: ticks))
    }

    /// QA only: advances the timeline to `elapsed` seconds for a review capture.
    ///
    /// The capture launch runs the update loop, but at a small fraction of
    /// wall-clock — it renders into a window that is never really presented — so
    /// a cutscene is only a few ticks in when the capture fires. Without this a
    /// timed cinematic always reviews as its opening beat.
    func seekForCapture(elapsed: TimeInterval) {
        guard runner.isPlaying else { return }
        // Seek to an absolute tick, not by a relative amount. The launch does run
        // *some* frames before the capture fires — far fewer than wall-clock, but
        // not none — and advancing by the full elapsed time on top of those put
        // the timeline past its own end.
        let target = max(0, Int(elapsed * LogicTickClock.ticksPerSecond))
        let remaining = max(0, target - runner.elapsedTicks)
        for _ in 0..<remaining where runner.isPlaying {
            apply(runner.advance(ticks: 1))
            advanceRails(LogicTickClock.tickDuration)
            // A camera scroll is retired by an `SKAction` timer, which will not
            // run here — resolve it in place. The viewport lands where the cue
            // pointed, which for a still frame is the whole of what it meant.
            apply(runner.noteCompleted(.camera))
        }
        // Actor cues are deliberately left in flight: the office harness seeks
        // Lila along her polyline by the same wall clock, and completing her walk
        // here would jump her to the desk in every mid-door review frame.
    }

    /// Unwinds a cutscene that a scene transition interrupted. Without this a
    /// router change mid-cutscene leaves an armed gate, hidden rails, and a
    /// camera nobody owns.
    func tearDown() {
        runner.reset()
        activeCutsceneID = nil
        releaseCamera()
        letterbox.setVisible(false, animated: false)
        fadeDuration = 0
        fadeOverlay.clear()
        overheadText?.removeFromParent()
        overheadText = nil
    }

    // MARK: - Camera

    /// The position the cutscene wants the camera at, if it owns it. Scenes ask
    /// before running their own follow so the two cannot fight — this replaces
    /// the shipped `cameraFollowSuspended` Bool, which had no owner and would
    /// race if two cues overlapped.
    func cameraOverride(in bounds: CGRect) -> CGPoint? {
        guard ownsCamera else { return nil }
        let target: CGPoint?
        if let actor = cameraFollowActor {
            target = stage?.cutsceneActor(actor)?.cutsceneWorldPosition
        } else {
            target = cameraTarget
        }
        return target.map { scene.clampedCameraPosition(following: $0, in: bounds) }
    }

    /// Applied after `layoutViewport()` has reset the base scale, so a cutscene
    /// push survives a window resize.
    func applyCameraScale() {
        guard ownsCamera, cameraScaleMultiplier != 1 else { return }
        scene.gameCamera.setScale(scene.baseCameraScale * cameraScaleMultiplier)
    }

    /// Advances every continuously-interpolated rail by one frame's worth of time.
    private func advanceRails(_ delta: TimeInterval) {
        if ownsCamera, cameraScaleDuration > 0 {
            cameraScaleElapsed += delta
            let progress = min(1, cameraScaleElapsed / cameraScaleDuration)
            cameraScaleMultiplier = cameraScaleFrom
                + (cameraScaleTo - cameraScaleFrom) * Self.smoothstep(progress)
            applyCameraScale()
            if progress >= 1 { cameraScaleDuration = 0 }
        }
        if fadeDuration > 0 {
            fadeElapsed += delta
            let progress = min(1, fadeElapsed / fadeDuration)
            fadeOverlay.show(fadeColor, alpha: fadeFrom + (fadeTo - fadeFrom) * progress)
            if progress >= 1 {
                fadeDuration = 0
                if fadeTo <= 0 { fadeOverlay.clear() }
            }
        }
    }

    private static func smoothstep(_ t: CGFloat) -> CGFloat { t * t * (3 - 2 * t) }

    private func startFade(to target: CGFloat, color: CutsceneColor, seconds: TimeInterval) {
        fadeColor = color
        fadeFrom = fadeOverlay.alpha
        fadeTo = target
        fadeElapsed = 0
        fadeDuration = max(0, seconds)
        guard fadeDuration <= 0 else {
            fadeOverlay.show(color, alpha: fadeFrom)
            return
        }
        target > 0 ? fadeOverlay.show(color, alpha: target) : fadeOverlay.clear()
    }

    private func releaseCamera() {
        ownsCamera = false
        cameraTarget = nil
        cameraFollowActor = nil
        cameraScaleDuration = 0
        cameraScaleMultiplier = 1
        scene.gameCamera.setScale(scene.baseCameraScale)
    }

    // MARK: - Dispatch

    private func apply(_ step: CutsceneStep) {
        for command in step.commands {
            perform(command.subject, command.cue)
        }
        guard let reason = step.completion else { return }
        let id = activeCutsceneID ?? ""
        activeCutsceneID = nil
        stage?.cutsceneDidComplete(id: id, reason: reason)
    }

    private func perform(_ subject: CutsceneSubject, _ cue: CutsceneCue) {
        // `ActionOverride` retargets the cue and reports back on the *issuing*
        // track — that is what makes it a join rather than a fork.
        if case .actionOverride(let actor, let inner) = cue {
            perform(.actor(actor), inner, reportingTo: subject)
            return
        }
        perform(subject, cue, reportingTo: subject)
    }

    private func perform(
        _ subject: CutsceneSubject,
        _ cue: CutsceneCue,
        reportingTo reporter: CutsceneSubject
    ) {
        let reason = completionReason
        switch cue {
        case .wait:
            break

        case .moveViewPoint(let point, let speed):
            ownsCamera = true
            cameraFollowActor = nil
            cameraTarget = point
            scheduleScrollCompletion(to: point, speed: speed, reporter: reporter)

        case .moveViewObject(let actor, let speed):
            ownsCamera = true
            cameraFollowActor = actor
            cameraTarget = nil
            let destination = stage?.cutsceneActor(actor)?.cutsceneWorldPosition
            scheduleScrollCompletion(to: destination, speed: speed, reporter: reporter)

        case .releaseCamera:
            releaseCamera()

        case .cameraScale(let scale, let beat):
            ownsCamera = true
            cameraScaleFrom = cameraScaleMultiplier
            cameraScaleTo = scale
            cameraScaleElapsed = 0
            cameraScaleDuration = reason.chromeDuration(beat.seconds)
            if cameraScaleDuration <= 0 {
                cameraScaleMultiplier = scale
                applyCameraScale()
            }

        case .fadeToColor(let color, let beat):
            startFade(
                to: CutsceneFadeNode.fullAlpha(for: color),
                color: color,
                seconds: reason.chromeDuration(beat.seconds)
            )

        case .fadeFromColor(let color, let beat):
            // A fade *from* a colour starts opaque, so seed it before easing out —
            // otherwise the first frame shows the scene the fade exists to hide.
            fadeOverlay.show(color, alpha: CutsceneFadeNode.fullAlpha(for: color))
            startFade(to: 0, color: color, seconds: reason.chromeDuration(beat.seconds))

        case .letterbox(let visible):
            letterbox.setVisible(visible, animated: reason == .natural)

        case .setCutsceneMode(let active):
            stage?.cutsceneSetMode(active, reason: reason)

        case .suppressDialogue:
            stage?.cutsceneSuppressDialogue()

        case .resumeDialogue(let nodeID):
            stage?.cutsceneResumeDialogue(nodeID: nodeID)

        case .moveToPoint(let point):
            drive(subject, reporter: reporter) { actor, done in
                actor.cutsceneFollow(path: [point], style: .plain, completion: done)
            }

        case .followPath(let path, let style):
            drive(subject, reporter: reporter) { actor, done in
                actor.cutsceneFollow(path: path, style: style, completion: done)
            }

        case .jumpToPoint(let point, let style):
            actorNode(subject)?.cutsceneJump(to: point, style: style)

        case .face(let facing):
            actorNode(subject)?.cutsceneFace(facing)

        case .faceObject(let target):
            guard let point = stage?.cutsceneActor(target)?.cutsceneWorldPosition else { break }
            actorNode(subject)?.cutsceneFace(toward: point)

        case .standUp:
            drive(subject, reporter: reporter) { actor, done in
                actor.cutsceneStandUp(completion: done)
            }

        case .displayStringHead(let key, let beat):
            showOverheadText(forKey: key, on: subject, seconds: beat.seconds)

        case .playVoiceOver(let asset):
            stage?.cutscenePlayVoiceOver(asset)

        case .setDoor(let door, let open):
            stage?.cutsceneSetDoor(door, open: open, reason: reason)

        case .setFlag(let flag):
            stage?.cutsceneSetFlag(flag)

        case .actionOverride:
            assertionFailure("Unwrapped in perform(_:_:)")
        }
    }

    /// A camera scroll blocks its track until it arrives, so the duration has to
    /// be resolved here — it is distance over rate, and only the director knows
    /// where the camera is standing when the cue starts.
    private func scheduleScrollCompletion(
        to destination: CGPoint?,
        speed: ScrollSpeed,
        reporter: CutsceneSubject
    ) {
        guard speed != .instant else { return }
        let from = scene.gameCamera.position
        let distance = destination.map {
            hypot($0.x - from.x, ($0.y - from.y) / ActorLocomotionPacing.verticalProjectionScale)
        } ?? 0
        let seconds = completionReason.chromeDuration(speed.beat(forDistance: distance).seconds)
        guard seconds > 0 else {
            report(reporter)
            return
        }
        scene.run(
            .sequence([.wait(forDuration: seconds), .run { [weak self] in self?.report(reporter) }]),
            withKey: "cutscene.scroll.\(reporter)"
        )
    }

    private func drive(
        _ subject: CutsceneSubject,
        reporter: CutsceneSubject,
        _ body: (CutsceneActorDriving, @escaping () -> Void) -> Void
    ) {
        guard let actor = actorNode(subject) else {
            report(reporter)
            return
        }
        body(actor) { [weak self] in self?.report(reporter) }
    }

    private func actorNode(_ subject: CutsceneSubject) -> CutsceneActorDriving? {
        guard case .actor(let id) = subject else { return nil }
        return stage?.cutsceneActor(id)
    }

    private func report(_ subject: CutsceneSubject) {
        guard runner.isPlaying else { return }
        apply(runner.noteCompleted(subject))
    }

    // MARK: - Chrome

    private func installChromeIfNeeded() {
        if letterbox.parent == nil { scene.cinematicRoot.addChild(letterbox) }
        if fadeOverlay.parent == nil { scene.cinematicRoot.addChild(fadeOverlay) }
        layoutChrome()
    }

    /// Called from the scene's layout pass — bars and overlay are sized to the
    /// viewport, not the plate.
    func layoutChrome() {
        letterbox.layout(viewport: scene.size)
        fadeOverlay.layout(viewport: scene.size)
    }

    private func showOverheadText(forKey key: String, on subject: CutsceneSubject, seconds: TimeInterval) {
        guard completionReason == .natural,
              let text = stage?.cutsceneText(forKey: key),
              let actor = actorNode(subject) as? SKNode else { return }
        overheadText?.removeFromParent()
        let node = OverheadTextNode(text: text)
        node.position = CGPoint(x: 0, y: OverheadTextNode.heightAboveActor)
        node.zPosition = SceneLayer.occlusion.rawValue
        actor.addChild(node)
        overheadText = node
        node.play(for: seconds)
    }
}
