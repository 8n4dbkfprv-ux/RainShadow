import CoreGraphics
import Foundation

/// A Baldur's Gate–shaped cutscene: a set of parallel tracks, each a sequential
/// list of cues.
///
/// The Infinity Engine's authoring model is two rules deep. A cutscene script
/// runs its blocks *once*, top to bottom, instead of the re-evaluate-from-the-top
/// loop ordinary BCS uses; and each block opens with `CutSceneId(Object)` naming
/// whose action list the block queues onto. Blocks with different `CutSceneId`s
/// therefore play **simultaneously**, while the actions inside one block run in
/// order and block each other. That is the whole concurrency model, and it is
/// what lets a BG cutscene say "the door falls *while* she walks in *while* he
/// gets to his feet" without a single callback.
///
/// `CutsceneTrack` is that block. Nothing here parses or evaluates IE script —
/// per `CinematicSystemRoadmap` §5.6 the patterns are ported, the language is not.
struct Cutscene: Equatable, Sendable {
    /// Stable id, used for logging and for the played-once guards scenes own.
    let id: String
    /// BG:EE `SetCutSceneBreakable`. Breakability is a per-sequence content flag
    /// in the engine, not a universal rule — Beamdog deliberately shipped
    /// unskippable sequences. A non-breakable cutscene still single-fires its
    /// completion, it just refuses skip.
    let isBreakable: Bool
    /// Seconds before a skip is accepted. The shipped exterior uses 1.0.
    let graceSeconds: TimeInterval
    let tracks: [CutsceneTrack]

    init(
        id: String,
        isBreakable: Bool = true,
        graceSeconds: TimeInterval = BreakableCutsceneGate.defaultGraceSeconds,
        tracks: [CutsceneTrack]
    ) {
        self.id = id
        self.isBreakable = isBreakable
        self.graceSeconds = graceSeconds
        self.tracks = tracks
    }
}

/// One `CutSceneId` block: cues run in order and block one another, while other
/// tracks advance in parallel.
struct CutsceneTrack: Equatable, Sendable {
    let subject: CutsceneSubject
    let cues: [CutsceneCue]

    init(_ subject: CutsceneSubject, _ cues: [CutsceneCue]) {
        self.subject = subject
        self.cues = cues
    }
}

/// Who a track is addressing — the `CutSceneId` object.
///
/// `.camera`, `.chrome`, and `.world` are not creatures in BG; the engine drives
/// them through whichever creature happens to hold the `CutSceneId`. Naming them
/// as their own subjects is the one deliberate divergence: it means a camera rail
/// and an actor walk cannot accidentally serialise behind each other, which in
/// BG is a real authoring hazard.
enum CutsceneSubject: Hashable, Sendable {
    /// Viewport position.
    case camera
    /// Viewport scale. Its own subject because BG has no zoom at all — the
    /// Infinity Engine camera only ever pans — so a push and a pan share no
    /// action in the engine and have no reason to serialise here. GDD §5.2
    /// allows restrained scale changes; this is where they live.
    case cameraZoom
    case chrome
    case world
    case actor(CutsceneActorID)
}

/// The creatures a cutscene can address. Deliberately closed: the office slice
/// ships exactly two actors, and a typo'd string id is a class of bug this
/// project has already paid for once in dialogue cue names.
enum CutsceneActorID: String, Hashable, Sendable, CaseIterable {
    case detective
    case client
}

/// `Wait(n)` vs `SmallWait(n)`.
///
/// IESDP: "`SmallWait` … the time is measured in AI updates (which default to 15
/// per second)". RainShadow already runs locomotion on exactly that clock
/// (`LogicTickClock.ticksPerSecond == 15`), so the two beat units collapse onto
/// one integer internally and a cutscene's timing is frame-rate independent for
/// the same reason the walk cycle is.
enum CutsceneBeat: Equatable, Sendable {
    /// BG `SmallWait(n)` — n AI updates.
    case ticks(Int)
    /// BG `Wait(n)` — n seconds.
    case seconds(TimeInterval)

    /// The beat in whole logic ticks. Sub-tick durations round up to one tick so
    /// an authored beat can never silently become a no-op.
    var ticks: Int {
        switch self {
        case .ticks(let count):
            return max(0, count)
        case .seconds(let seconds):
            guard seconds > 0 else { return 0 }
            return max(1, Int((seconds * LogicTickClock.ticksPerSecond).rounded()))
        }
    }

    var seconds: TimeInterval {
        TimeInterval(ticks) * LogicTickClock.tickDuration
    }

    static let instant = CutsceneBeat.ticks(0)
}

/// `scroll.ids` — the engine's closed set of view-scroll speeds.
///
/// IESDP documents `MoveViewPoint`'s speed parameter as taking these five values
/// and notes that **`VERY_FAST` is equivalent to normal walking speed**. That
/// comparison is the useful part: BG does not let an author pick an arbitrary
/// camera duration, it picks a *rate*, and the fastest rate is the one the
/// player's own feet move at. Anchoring `.veryFast` to `ActorLocomotionPacing.walkSpeed`
/// keeps that relationship true if the sprite is ever rebaked at a different
/// body height, the same way the walk itself is derived rather than hard-coded.
enum ScrollSpeed: Int, Equatable, Sendable, CaseIterable {
    case instant = 0
    case slow = 1
    case standard = 2
    case fast = 3
    case veryFast = 4

    /// Projected world units per second, or `nil` for an instant cut.
    var pointsPerSecond: CGFloat? {
        switch self {
        case .instant: nil
        case .slow: ActorLocomotionPacing.walkSpeed * 0.35
        case .standard: ActorLocomotionPacing.walkSpeed * 0.6
        case .fast: ActorLocomotionPacing.walkSpeed * 0.8
        case .veryFast: ActorLocomotionPacing.walkSpeed
        }
    }

    /// Time to scroll `distance` projected units at this speed.
    func beat(forDistance distance: CGFloat) -> CutsceneBeat {
        guard let rate = pointsPerSecond, rate > 0, distance > 0 else { return .instant }
        return .seconds(TimeInterval(distance / rate))
    }
}

/// Colours a `fadeToColor` cue can reach. BG passes a packed RGB; the shipped
/// palette is small enough that naming the two in use beats carrying a colour
/// through a SpriteKit-free module.
enum CutsceneColor: Equatable, Sendable {
    case black
    /// The exterior's additive window bloom — the warm cut into the office.
    case warmWindowBloom
}

/// How a scripted walk presents at the threshold.
///
/// Not an Infinity Engine concept — BG creatures simply appear and disappear at
/// area edges. RainShadow fades its client through the office doorway instead,
/// and the fade is part of the walk rather than a separate cue because a skip
/// has to land on the same end state: visible and standing for an arrival,
/// hidden past the door for a departure.
enum CutsceneWalkStyle: Equatable, Sendable {
    /// Ordinary locomotion; the actor is visible throughout.
    case plain
    /// Fades up crossing the threshold inward.
    case entering
    /// Fades out at the door and ends hidden.
    case leaving
}

/// Doors a `.world` track can operate. Opening one clears its search-map cells,
/// which BG:EE also does before a creature paths through.
enum CutsceneDoorID: String, Equatable, Sendable {
    case officeEntrance
}

/// A single authored beat.
///
/// Every case maps to a documented Infinity Engine action; the comment names it.
/// Cues fall into two execution classes, exactly as they do in BG:
///
/// - **Timed** — the runner knows the duration up front and retires the cue
///   itself (`Wait`, `FadeToColor`, `MoveViewPoint`).
/// - **Open-ended** — completion depends on the world, so the director reports
///   back (`MoveToPoint` blocks until arrival; so does ours).
enum CutsceneCue: Equatable, Sendable {

    // MARK: Timing

    /// `Wait` / `SmallWait`.
    case wait(CutsceneBeat)

    // MARK: Camera

    /// `MoveViewPoint(P:Target, I:ScrollSpeed*Scroll)`.
    case moveViewPoint(CGPoint, ScrollSpeed)
    /// `MoveViewObject(O:Target, I:ScrollSpeed*Scroll)` — scroll to follow an actor.
    case moveViewObject(CutsceneActorID, ScrollSpeed)
    /// Hand the camera back to gameplay follow. BG's `UnlockScroll` neighbour.
    case releaseCamera
    /// Camera scale, as a multiple of the scene's resolved base zoom. GDD §5.2
    /// restricts cinematic movement to slow pans, pushes, and restrained scale.
    case cameraScale(CGFloat, CutsceneBeat)

    // MARK: Chrome

    /// `FadeToColor([Duration.0], I:Color)`.
    case fadeToColor(CutsceneColor, CutsceneBeat)
    /// `FadeFromColor([Duration.0], I:Color)`.
    case fadeFromColor(CutsceneColor, CutsceneBeat)
    /// Letterbox bars. Not an IE action — IE hides the whole GUI instead — but it
    /// is this project's shipped `StartCutSceneMode` tell.
    case letterbox(Bool)
    /// `StartCutSceneMode` / `EndCutSceneMode`: free-play rails and player input.
    case setCutsceneMode(Bool)
    /// Hide the dialogue panel without moving the graph (`shouldDeferAdvance`).
    case suppressDialogue
    /// Reopen the panel, advancing the deferred session to `nodeID`.
    case resumeDialogue(nodeID: String?)

    // MARK: Actor

    /// `MoveToPoint(P:Point)` — routed through `NavigationMap`. Blocks until arrival.
    case moveToPoint(CGPoint)
    /// Walk an authored polyline. Still `RouteFollower` locomotion, not an
    /// `SKAction` chain — see `OfficeNavigationLayout.clientArrivalRoute`, which
    /// deliberately refuses A* because snapping interior anchors onto the nearest
    /// walkable cell walks the coat through frosted glass beside the real opening.
    case followPath([CGPoint], CutsceneWalkStyle)
    /// `JumpToPoint(P:Target)` — teleport. BG's restage idiom is `FadeToColor`,
    /// `JumpToPoint` for each actor, `FadeFromColor`.
    case jumpToPoint(CGPoint, CutsceneWalkStyle)
    /// `Face(I:Direction*Dir)` — one of the sixteen orientation bins.
    case face(ActorFacing)
    /// `FaceObject(O:Target)`. Standing creatures turn one bin per tick
    /// (GemRB `GetNextFace`), which `ActorFacing.stepped(toward:)` already models.
    case faceObject(CutsceneActorID)
    /// Rise from the desk chair. Blocks until the stand-up strip finishes.
    case standUp
    /// `DisplayStringHead(O:Object, I:StrRef)` — floating text over an actor,
    /// resolved through `DialogueStringTable`. Says something without opening
    /// the dialogue panel.
    case displayStringHead(stringKey: String, CutsceneBeat)
    /// `PlaySound` / voice-over one-shot.
    case playVoiceOver(String)

    // MARK: World

    /// Door state plus its search-map cells. BG:EE clears a door's cells before
    /// a creature paths through it.
    case setDoor(CutsceneDoorID, open: Bool)
    /// `SetGlobal` — the guard flag that stops a cutscene re-firing.
    case setFlag(String)

    // MARK: Cross-actor

    /// `ActionOverride(O:Actor, A:Action)` — run one cue on another actor and
    /// **block this track until it finishes**.
    ///
    /// This is BG's join. Separate `CutSceneId` blocks give you concurrency;
    /// `ActionOverride` is how a block waits for someone else's work before
    /// continuing, and it is why the office's letterbox-down and dialogue-resume
    /// can sit in one readable list instead of a completion callback. The
    /// engine's own hazard applies unchanged: an override and that actor's own
    /// track both driving them at once is an authoring error, not a merge.
    indirect case actionOverride(CutsceneActorID, CutsceneCue)

    /// Whether the runner must wait for the director to report completion.
    ///
    /// This is BG's own split: `Wait` is engine-timed, `MoveToPoint` blocks until
    /// the creature actually arrives.
    var isOpenEnded: Bool {
        switch self {
        case .moveToPoint, .followPath, .standUp:
            true
        case .actionOverride(_, let inner):
            inner.isOpenEnded
        case .moveViewPoint(_, let speed), .moveViewObject(_, let speed):
            // IESDP: the scroll runs *to* the target at the given rate, so the
            // block waits on it. Only the runner cannot know how long that is —
            // duration is distance over rate, and the distance depends on where
            // the camera is standing when the cue starts. The director resolves
            // it and reports back, which is also what makes `.veryFast` mean the
            // same thing as a walk regardless of how far the scroll runs.
            speed != .instant
        default:
            false
        }
    }

    /// How long a timed cue occupies its track. Open-ended cues report `.instant`
    /// because their duration is not knowable up front.
    var duration: CutsceneBeat {
        switch self {
        case .wait(let beat),
             .fadeToColor(_, let beat),
             .fadeFromColor(_, let beat),
             .displayStringHead(_, let beat),
             .cameraScale(_, let beat):
            beat
        case .actionOverride(_, let inner):
            inner.duration
        default:
            .instant
        }
    }

    /// The same cue with every duration collapsed to zero.
    ///
    /// This is what makes "skip and natural completion share one terminal state"
    /// a structural property rather than two hand-maintained code paths. A skipped
    /// cutscene replays *every remaining cue* in terminal form, so it cannot
    /// forget to set a flag, open a door, or resume the dialogue graph — the
    /// class of bug the shipped `finishClientEntrance` has to guard by hand.
    var terminal: CutsceneCue {
        switch self {
        case .wait:
            .wait(.instant)
        case .moveViewPoint(let point, _):
            .moveViewPoint(point, .instant)
        case .moveViewObject(let actor, _):
            .moveViewObject(actor, .instant)
        case .cameraScale(let scale, _):
            .cameraScale(scale, .instant)
        case .fadeToColor(let color, _):
            .fadeToColor(color, .instant)
        case .fadeFromColor(let color, _):
            .fadeFromColor(color, .instant)
        case .displayStringHead:
            // A line nobody had time to read is a line the skip should drop, not
            // flash for one frame. Everything else about the cue is presentation.
            .wait(.instant)
        case .actionOverride(let actor, let inner):
            .actionOverride(actor, inner.terminal)
        case .moveToPoint(let point):
            .jumpToPoint(point, .plain)
        case .followPath(let path, let style):
            // The endpoint alone is not the end state: an arrival must be left
            // visible and a departure hidden, which is exactly the pair the
            // shipped `completeEntranceImmediately` / `completeExitImmediately`
            // draw. Carrying the style through the terminal form is what keeps
            // a broken walk from leaving the client standing in a closed doorway.
            path.last.map { CutsceneCue.jumpToPoint($0, style) } ?? .wait(.instant)
        default:
            self
        }
    }
}
