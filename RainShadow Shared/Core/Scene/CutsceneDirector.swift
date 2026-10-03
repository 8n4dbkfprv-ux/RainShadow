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
    var cutsceneNavigationID: String { get }
    /// Drives the engine navigation path returned for MoveToPoint.
    func cutsceneFollow(path: [CGPoint], completion: @escaping () -> Void)
    /// `JumpToPoint` — teleport, and land in the pose the walk would have left.
    func cutsceneJump(to point: CGPoint)
    /// `Face(dir)`.
    func cutsceneFace(_ facing: ActorFacing)
    /// `FaceObject` — immediate scripted orientation (dialogue turning is separate).
    func cutsceneFace(toward point: CGPoint)
    /// HideCreature changes the avatar visibility immediately.
    func cutsceneSetHidden(_ hidden: Bool)
    func cutsceneClearActions()
    func cutscenePlaySequence(_ sequence: CutsceneSequence, completion: @escaping () -> Void)
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
    /// Recovery commands retain their authored timing and their completion reason.
    private var completionReason: CutsceneCompletionReason = .natural

    // Camera rail.
    private(set) var ownsCamera = false
    private var viewport: CutsceneViewport?
    private var scrollReporters: Set<CutsceneSubject> = []
    private var generation = 0
    private var sequences: [CutsceneSubject: CutsceneSequence] = [:]
    private var sequenceIDs: [CutsceneSubject: Int] = [:]
    private var actorCommandIDs: [CutsceneSubject: Int] = [:]
    private var pendingSteps: [(Int, CutsceneStep)] = []
    private var applying = false
    // Black fade overlay, driven by the engine timer in CutsceneRunner.
    private lazy var fadeOverlay = CutsceneFadeNode()
    private var overheadTexts: [CutsceneSubject: OverheadTextNode] = [:]

    init(scene: BaseGameScene) {
        self.scene = scene
    }

    var isPlaying: Bool { runner.isPlaying }
    private(set) var isCutsceneMode = false
    var freezesWorld: Bool { runner.isFading }

    // MARK: - Lifecycle

    func play(_ cutscene: Cutscene, on stage: CutsceneStage) {
        tearDown()
        self.stage = stage
        scene.setCameraScroll(.zero)
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
        guard isCutsceneMode else { return false }
        // Cutscene mode owns this event during an unbreakable beat.
        guard runner.canSkip(at: ProcessInfo.processInfo.systemUptime) else { return true }
        generation += 1
        scrollReporters = []
        viewport = CutsceneViewport(position: scene.gameCamera.position)
        completionReason = .skipped
        overheadTexts.values.forEach { $0.removeFromParent() }
        overheadTexts = [:]
        apply(runner.skip(at: ProcessInfo.processInfo.systemUptime))
        return true
    }

    /// Drives the timeline. Called from the scene's `update(_:)`.
    func update(_ currentTime: TimeInterval) {
        // Global viewport and fade timers continue after action queues empty.
        let delta = lastUpdateTime.map {
            min(max(0, currentTime - $0), ActorLocomotionPacing.maximumFrameDelta)
        } ?? 0
        lastUpdateTime = currentTime
        let ticks = clock.drain(deltaTime: delta)
        for _ in 0..<ticks {
            advanceViewport()
            apply(runner.advance(ticks: 1))
            renderFade()
            if viewport?.isMoving == false { finishScroll() }
        }
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
            advanceViewport()
            apply(runner.advance(ticks: 1))
            renderFade()
            if viewport?.isMoving == false { finishScroll() }
        }
        // Actor cues are deliberately left in flight: the office harness seeks
        // Lila along her polyline by the same wall clock, and completing her walk
        // here would jump her to the desk in every mid-door review frame.
    }

    /// Unwinds a cutscene that a scene transition interrupted. Without this a
    /// router change mid-cutscene leaves an armed gate, hidden rails, and a
    /// camera nobody owns.
    func tearDown() {
        if isCutsceneMode { stage?.cutsceneSetMode(false, reason: .skipped) }
        isCutsceneMode = false
        scene.hudRoot.isHidden = false
        if runner.isPlaying {
            for actor in CutsceneActorID.allCases { stage?.cutsceneActor(actor)?.cutsceneClearActions() }
        }
        generation += 1
        actorCommandIDs = [:]
        sequences = [:]
        sequenceIDs = [:]
        pendingSteps = []
        runner.reset()
        activeCutsceneID = nil
        releaseCamera()
        fadeOverlay.clear()
        overheadTexts.values.forEach { $0.removeFromParent() }
        overheadTexts = [:]
    }

    // MARK: - Camera

    /// The position the cutscene wants the camera at, if it owns it. Scenes ask
    /// before running their own follow so the two cannot fight — this replaces
    /// the shipped `cameraFollowSuspended` Bool, which had no owner and would
    /// race if two cues overlapped.
    func cameraOverride(in bounds: CGRect) -> CGPoint? {
        guard ownsCamera else { return nil }
        return viewport.map { scene.clampedCameraPosition(following: $0.position, in: bounds) }
    }

    private func renderFade() {
        fadeOverlay.show(.black, alpha: CGFloat(runner.fade.alpha) / 255)
    }

    private func releaseCamera() {
        ownsCamera = false
        viewport = nil
        scrollReporters = []
    }

    // MARK: - Dispatch

    private func apply(_ step: CutsceneStep) {
        pendingSteps.append((generation, step))
        guard !applying else { return }
        applying = true
        defer { applying = false }
        while !pendingSteps.isEmpty {
            let (issuedGeneration, next) = pendingSteps.removeFirst()
            guard issuedGeneration == generation else { continue }
            for command in next.commands {
                guard issuedGeneration == generation else { break }
                perform(command.subject, command.cue, reportingTo: command.subject)
            }
            guard issuedGeneration == generation, let reason = next.completion else { continue }
            let id = activeCutsceneID ?? ""
            activeCutsceneID = nil
            stage?.cutsceneDidComplete(id: id, reason: reason)
        }
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
            moveViewport(to: point, speed: speed, reporter: nil)

        case .moveViewPointUntilDone(let point, let speed):
            moveViewport(to: point, speed: speed, reporter: speed == .instant ? nil : reporter)

        case .moveViewObject(let actor, let speed):
            // A snapshot, not a tracking camera (Actions.cpp passes scr->Pos once).
            if let point = stage?.cutsceneActor(actor)?.cutsceneWorldPosition {
                moveViewport(to: point, speed: speed, reporter: nil)
            }

        case .releaseCamera:
            releaseCamera()

        case .fadeToColor, .fadeFromColor:
            renderFade()

        case .setCutsceneBreakable:
            break // The runner owns the gate.

        case .setCutsceneMode(let active):
            isCutsceneMode = active
            scene.hudRoot.isHidden = active
            if active { scene.prepareCutsceneInput() }
            stage?.cutsceneSetMode(active, reason: reason)

        case .suppressDialogue:
            stage?.cutsceneSuppressDialogue()

        case .resumeDialogue(let nodeID):
            stage?.cutsceneResumeDialogue(nodeID: nodeID)

        case .moveToPoint(let point):
            drive(subject, reporter: reporter) { [self] actor, done in
                guard let area = scene as? GameAreaScene else { done(); return }
                let path = area.navigation.pathAvoidingActors(
                    from: actor.cutsceneWorldPosition, to: point,
                    identity: actor.cutsceneNavigationID
                )
                actor.cutsceneFollow(
                    path: [actor.cutsceneWorldPosition] + path.nodes.map(\.point),
                    completion: done
                )
            }

        case .jumpToPoint(let point):
            actorNode(subject)?.cutsceneJump(to: point)

        case .hideCreature(let hidden):
            actorNode(subject)?.cutsceneSetHidden(hidden)

        case .face(let facing):
            actorNode(subject)?.cutsceneFace(facing)

        case .faceObject(let target):
            guard let point = stage?.cutsceneActor(target)?.cutsceneWorldPosition else { break }
            actorNode(subject)?.cutsceneFace(toward: point)

        case .playSequence(let sequence):
            guard let actor = actorNode(subject) else { break }
            sequences[subject] = sequence
            sequenceIDs[subject, default: 0] += 1
            let sequenceID = sequenceIDs[subject]
            let issuedGeneration = generation
            actor.cutscenePlaySequence(sequence) { [weak self] in
                guard let self, self.generation == issuedGeneration,
                      self.sequenceIDs[subject] == sequenceID else { return }
                self.sequences[subject] = nil
                self.apply(self.runner.noteAnimationCompleted(subject, sequence: sequence))
            }

        case .waitAnimation(let sequence):
            if sequences[subject] != sequence {
                apply(runner.noteAnimationCompleted(subject, sequence: sequence))
            }

        case .displayStringHead(let key, let beat):
            showOverheadText(forKey: key, on: subject, seconds: beat.seconds)

        case .playVoiceOver(let asset):
            stage?.cutscenePlayVoiceOver(asset)

        case .setDoor(let door, let open):
            stage?.cutsceneSetDoor(door, open: open, reason: reason)

        case .setFlag(let flag):
            stage?.cutsceneSetFlag(flag)

        case .clearActions:
            actorCommandIDs[subject, default: 0] += 1
            sequences[subject] = nil
            sequenceIDs[subject, default: 0] += 1
            actorNode(subject)?.cutsceneClearActions()

        case .actionOverride:
            assertionFailure("Queue operations are resolved by CutsceneRunner")
        }
    }

    private func moveViewport(to point: CGPoint, speed: ScrollSpeed, reporter: CutsceneSubject?) {
        ownsCamera = true
        if viewport == nil { viewport = CutsceneViewport(position: scene.gameCamera.position) }
        viewport?.move(to: point, speed: speed)
        if let reporter { scrollReporters.insert(reporter) }
        if speed == .instant {
            scene.gameCamera.position = scene.clampedCameraPosition(following: point, in: scene.cameraClampBounds)
        }
        if viewport?.isMoving == false { finishScroll() }
    }

    private func advanceViewport() {
        guard var rail = viewport else { return }
        let previous = rail.position
        rail.advance()
        let clamped = scene.clampedCameraPosition(following: rail.position, in: scene.cameraClampBounds)
        rail.reconcile(clamped: clamped, previous: previous)
        viewport = rail
    }

    private func finishScroll() {
        let reporters = scrollReporters
        scrollReporters = []
        for reporter in reporters { report(reporter) }
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
        actorCommandIDs[subject, default: 0] += 1
        let commandID = actorCommandIDs[subject]
        let issuedGeneration = generation
        body(actor) { [weak self] in
            guard let self, self.generation == issuedGeneration,
                  self.actorCommandIDs[subject] == commandID else { return }
            self.report(reporter)
        }
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
        if fadeOverlay.parent == nil { scene.cinematicRoot.addChild(fadeOverlay) }
        layoutChrome()
    }

    /// Called from the scene's layout pass — the overlay is sized to the
    /// viewport, not the plate.
    func layoutChrome() {
        fadeOverlay.layout(viewport: scene.size)
    }

    private func showOverheadText(forKey key: String, on subject: CutsceneSubject, seconds: TimeInterval) {
        guard let text = stage?.cutsceneText(forKey: key),
              let actor = actorNode(subject) as? SKNode else { return }
        overheadTexts[subject]?.removeFromParent()
        let node = OverheadTextNode(text: text)
        node.position = CGPoint(x: 0, y: OverheadTextNode.heightAboveActor)
        node.zPosition = SceneLayer.occlusion.rawValue
        actor.addChild(node)
        overheadTexts[subject] = node
        node.play(for: seconds)
    }
}
