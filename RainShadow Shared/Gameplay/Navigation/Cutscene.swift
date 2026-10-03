import CoreGraphics
import Foundation

/// A Baldur's Gate–shaped cutscene: a set of parallel tracks, each a sequential
/// list of cues.
///
/// The Infinity Engine's authoring model is two rules deep. A cutscene script
/// runs its blocks *once*, top to bottom, instead of the re-evaluate-from-the-top
/// loop ordinary BCS uses; and each block opens with `CutSceneId(Object)` naming
/// whose action list the block queues onto. Repeated subjects append to one queue.
/// Blocks with different `CutSceneId`s
/// therefore play **simultaneously**, while the actions inside one block run in
/// order, yielding only for blocking actions. That is the whole concurrency model, and it is
/// what lets a BG cutscene say "the door falls *while* she walks in *while* he
/// gets to his feet" without a single callback.
///
/// `CutsceneTrack` is that block. Nothing here parses or evaluates IE script —
/// see `CinematicSystemRoadmap`: action semantics are ported, the language is not.
struct Cutscene: Equatable, Sendable {
    /// Stable id, used for logging and for the played-once guards scenes own.
    let id: String
    /// BG:EE `SetCutSceneBreakable`. Breakability is a per-sequence content flag
    /// in the engine, not a universal rule — Beamdog deliberately shipped
    /// unskippable sequences. A non-breakable cutscene still single-fires its
    /// completion, it just refuses skip.
    let isBreakable: Bool
    let tracks: [CutsceneTrack]
    /// Authored EE-style failsafe. World-dependent recovery must be explicit.
    let skipTracks: [CutsceneTrack]?

    init(
        id: String,
        isBreakable: Bool = false,
        tracks: [CutsceneTrack],
        skipTracks: [CutsceneTrack]? = nil
    ) {
        self.id = id
        self.isBreakable = isBreakable
        self.tracks = tracks
        self.skipTracks = skipTracks
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

/// The Scriptable whose action queue receives the CutSceneId block. The
/// opening uses the world script; office choreography uses the actual actors.
enum CutsceneSubject: Hashable, Sendable {
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
    case seconds(Int)

    /// Wait takes integer seconds; SmallWait takes integer engine updates.
    var ticks: Int {
        switch self {
        case .ticks(let count):
            return max(0, count)
        case .seconds(let seconds):
            guard seconds > 0 else { return 0 }
            return seconds * Int(LogicTickClock.ticksPerSecond)
        }
    }

    var seconds: TimeInterval {
        TimeInterval(ticks) * LogicTickClock.tickDuration
    }

    static let instant = CutsceneBeat.ticks(0)
}

/// GemRB Actions.cpp passes `ScrollSpeed << 1` to GlobalTimer: projected
/// pixels per 15 Hz tick. Camera motion is not a ground-plane actor walk.
enum ScrollSpeed: Int, Equatable, Sendable, CaseIterable {
    case instant = 0
    case slow = 1
    case standard = 2
    case fast = 3
    case veryFast = 4

    var pointsPerTick: CGFloat { CGFloat(rawValue << 1) }
    var pointsPerSecond: CGFloat? {
        self == .instant ? nil : pointsPerTick * LogicTickClock.ticksPerSecond
    }

    func beat(forDistance distance: CGFloat) -> CutsceneBeat {
        guard pointsPerTick > 0, distance > 0 else { return .instant }
        return .ticks(Int(ceil(distance / pointsPerTick)))
    }
}

/// The pinned engine's FadeToColor/FadeFromColor actions fade black.
enum CutsceneColor: Equatable, Sendable {
    case black
}

/// The shipped actor animation used by PlaySequence / WaitAnimation.
enum CutsceneSequence: Equatable, Sendable {
    case getUp
}

/// Doors a `.world` track can operate. Opening one clears its search-map cells,
/// which BG:EE also does before a creature paths through.
enum CutsceneDoorID: String, Equatable, Sendable {
    case officeEntrance
}

/// A single authored beat.
///
/// IE actions retain engine semantics; project-only choreography is labelled explicitly.
enum CutsceneCue: Equatable, Sendable {

    // MARK: Timing

    /// `Wait` / `SmallWait`.
    case wait(CutsceneBeat)

    // MARK: Camera

    /// `MoveViewPoint(P:Target, I:ScrollSpeed*Scroll)`.
    case moveViewPoint(CGPoint, ScrollSpeed)
    /// The distinct blocking IE action, `MoveViewPointUntilDone`.
    case moveViewPointUntilDone(CGPoint, ScrollSpeed)
    /// `MoveViewObject(O:Target, I:ScrollSpeed*Scroll)` — scroll to the actor’s position at dispatch.
    case moveViewObject(CutsceneActorID, ScrollSpeed)
    /// Hand the camera back to gameplay follow. BG's `UnlockScroll` neighbour.
    case releaseCamera
    // MARK: Chrome

    /// `FadeToColor([Duration.0], I:Color)`.
    case fadeToColor(CutsceneColor, CutsceneBeat)
    /// `FadeFromColor([Duration.0], I:Color)`.
    case fadeFromColor(CutsceneColor, CutsceneBeat)
    /// `StartCutSceneMode` / `EndCutSceneMode`: free-play rails and player input.
    case setCutsceneMode(Bool)
    /// BG:EE SetCutSceneBreakable: takes effect immediately.
    case setCutsceneBreakable(Bool)
    /// Hide the dialogue panel without moving the graph (`shouldDeferAdvance`).
    case suppressDialogue
    /// Reopen the panel, advancing the deferred session to `nodeID`.
    case resumeDialogue(nodeID: String?)

    // MARK: Actor

    /// `MoveToPoint(P:Point)` — routed through `NavigationMap`. Blocks until arrival.
    case moveToPoint(CGPoint)
    /// `JumpToPoint(P:Target)` — teleport. BG's restage idiom is `FadeToColor`,
    /// `JumpToPoint` for each actor, `FadeFromColor`.
    case jumpToPoint(CGPoint)
    /// HideCreature: change visibility without fading or suspending scripts.
    case hideCreature(Bool)
    /// `Face(I:Direction*Dir)` — one of the sixteen orientation bins.
    case face(ActorFacing)
    /// `FaceObject(O:Target)` snaps; slow dialogue orientation is a separate action.
    case faceObject(CutsceneActorID)
    /// PlaySequence starts an actor stance without blocking its action list.
    case playSequence(CutsceneSequence)
    /// WaitAnimation waits until that stance finishes, with the engine round cap.
    case waitAnimation(CutsceneSequence)
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

    /// Queues work on the target and immediately releases the issuer.
    /// BG2 clears the target's ordinary actions, preserving previous overrides.
    indirect case actionOverride(CutsceneActorID, CutsceneCue)

    /// Clear the actor's current movement when an override replaces its queue.
    case clearActions

    var isOpenEnded: Bool {
        switch self {
        case .moveToPoint, .waitAnimation: true
        case .moveViewPointUntilDone(_, let speed): speed != .instant
        default: false
        }
    }

    /// Presentation lifetimes do not block an actor's action list. Fades suspend
    /// script processing globally in the pinned GemRB timer, handled by the runner.
    var duration: CutsceneBeat {
        switch self {
        case .wait(let beat): beat
        case .face, .faceObject: .ticks(1) // SetOrientation(..., false); SetWait(1)
        default: .instant
        }
    }

}
