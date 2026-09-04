import Foundation

/// When a footstep is allowed to sound.
///
/// The obvious implementation triggers on the walk cycle's contact frames. BG
/// does not do that. `Actor::PlayWalkSound` gates purely on the previous clip
/// having finished:
///
///     if (thisTime < Timers.nextWalkSound) return;
///     ...
///     Timers.nextWalkSound = ieDword(thisTime + length);
///
/// So the cadence is clip-length driven, which is why BG's footsteps sit loosely
/// against the gait rather than locking to it. That looseness is part of the
/// texture; frame-locking them would sound tighter than the game we are matching.
///
/// The engine also refuses to play at all outside the walk stance, and while
/// dialogue or frozen scripts hold the world (`Actor::Update` checks
/// `DF_IN_DIALOG | DF_FREEZE_SCRIPTS` before reaching the footstep call).
struct FootstepCadence: Equatable, Sendable {
    /// Seconds between footfalls implied by the authored gait: one walk cycle
    /// carries two steps.
    ///
    /// BG needs no such number — its walk sounds were authored long enough that
    /// clip length alone paced them. Ours are not guaranteed to be: a tight 0.1s
    /// sample would fire six times a second under a pure clip-length gate, which
    /// is a sprint, not a walk. So the engine's rule stays primary and this floors
    /// it. One deliberate divergence, and the direction that fails safe.
    static var strideInterval: TimeInterval {
        (Double(ActorLocomotionPacing.walkFramesPerCycle)
            * ActorLocomotionPacing.walkCycleSecondsPerFrame) / 2
    }

    private var nextAllowedTime: TimeInterval = -.greatestFiniteMagnitude

    /// True when a footfall may start now. `silenced` covers pause and dialogue.
    ///
    /// The tolerance is the same one `LogicTickClock.drain` needs and for the same
    /// reason: a caller advancing time by repeated addition of a tick lands a few
    /// ULPs below where exact arithmetic would put it. Comparing strictly makes
    /// the step wait one whole extra tick, and since the stride is only four
    /// ticks, that reads as a limp.
    func allowsStep(at now: TimeInterval, isWalking: Bool, silenced: Bool) -> Bool {
        guard isWalking, !silenced else { return false }
        return now + LogicTickClock.tickDuration * 1e-6 >= nextAllowedTime
    }

    /// Records that a clip of `clipDuration` just started, which is what holds the
    /// next one off.
    mutating func noteStepStarted(at now: TimeInterval, clipDuration: TimeInterval) {
        nextAllowedTime = now + max(Self.strideInterval, clipDuration)
    }

    /// Clears the hold so the next step sounds immediately — used when the actor
    /// stops, so the first footfall of the next walk is not swallowed by a stale
    /// tail from the last one.
    mutating func reset() {
        nextAllowedTime = -.greatestFiniteMagnitude
    }
}

/// How often a character acknowledges an order or a selection out loud.
///
/// BG exposes this as a slider and reads it as a ladder in `Actor::CommandActor`
/// and `Actor::PlaySelectionSound`. `Baldur.lua` ships
/// `Command Sounds Frequency = 2` and `Selection Sounds Frequency = 3`.
enum BarkFrequency: Int, CaseIterable, Sendable {
    case never = 1
    /// One bark per selection, then silence until reselected.
    case oncePerSelection = 2
    case half = 3
    case mostly = 4
    case always = 5

    /// Chance in 100, for the levels that roll. BG's own numbers: level 3 is
    /// `RAND(1,100) > 50` and level 4 is `> 80`.
    var chanceInHundred: Int {
        switch self {
        case .never: 0
        case .oncePerSelection: 100
        case .half: 50
        case .mostly: 80
        case .always: 100
        }
    }
}

/// Decides whether a bark sounds, given BG's ladder.
///
/// One adaptation, and it is deliberate. BG's level 2 means "once per selection",
/// which works for a six-portrait party where selection changes constantly. With
/// a single detective who is always selected, a literal port barks once per
/// session. So "selection" here means re-acquiring the actor — clicking his
/// portrait, or dialogue ending — and the shipped default is `.half` rather than
/// BG's `.oncePerSelection`, which is the level that reads right for one body.
///
/// BG also collapses its own selection ladder: `PlaySelectionSound` promotes any
/// level above 2 straight to `always` outside PST, so the slider really only
/// distinguishes off, once, and every time. The ladder is kept intact here
/// because the intermediate levels are what make one actor bearable.
struct BarkGate: Equatable, Sendable {
    var frequency: BarkFrequency
    /// BG drops a "rare select" line ~5% of the time (`RARE_SELECT_CHANCE`).
    var rareChanceInHundred: Int
    private var playedSinceSelection = false

    init(frequency: BarkFrequency = .half, rareChanceInHundred: Int = 5) {
        self.frequency = frequency
        self.rareChanceInHundred = rareChanceInHundred
    }

    /// The actor was (re)selected: `oncePerSelection` is armed again.
    mutating func noteSelected() {
        playedSinceSelection = false
    }

    enum Outcome: Equatable, Sendable {
        case silent
        case common
        case rare
    }

    /// `roll` and `rareRoll` are 1...100, injected so the ladder is testable
    /// rather than merely exercised.
    mutating func resolve(roll: Int, rareRoll: Int) -> Outcome {
        switch frequency {
        case .never:
            return .silent
        case .oncePerSelection:
            if playedSinceSelection { return .silent }
            playedSinceSelection = true
        case .half, .mostly:
            if roll > frequency.chanceInHundred { return .silent }
        case .always:
            break
        }
        return rareRoll <= rareChanceInHundred ? .rare : .common
    }
}

/// The idle glance, and the idle comment.
///
/// `Scriptable::ProcessActions` runs scripts on a 16-tick stride staggered per
/// actor (`if (Ticks % 16 != globalID % 16)`), and `Actor::IdleActions` then rolls
/// `RAND(0, 24)`, playing a head-turn on zero while the stance is `AWAKE`. At
/// 15 Hz that is a 1-in-25 chance about every 1.07 s, so a standing character
/// glances around roughly every 27 seconds — present, but nowhere near fidgeting.
struct IdleBehaviourClock: Equatable, Sendable {
    /// BG's script stride, in logic ticks.
    static let scriptStrideTicks = 16
    /// `RAND(0, 24)` — one chance in 25 per script pass.
    static let headTurnOdds = 25

    /// Staggers this actor against the others, as `globalID % 16` does.
    let phase: Int
    private var tick = 0

    init(phase: Int = 0) {
        self.phase = ((phase % Self.scriptStrideTicks) + Self.scriptStrideTicks) % Self.scriptStrideTicks
    }

    /// Advances one logic tick; true when this actor's script pass lands here.
    mutating func advanceTickRunsScript() -> Bool {
        let runs = tick % Self.scriptStrideTicks == phase
        tick += 1
        return runs
    }

    /// `roll` is 0..<`headTurnOdds`, matching `RAND(0, 24)`.
    static func rollWantsHeadTurn(_ roll: Int) -> Bool { roll == 0 }
}
