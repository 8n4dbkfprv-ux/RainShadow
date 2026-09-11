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
/// Raw values are `Baldur.lua`'s `Command Sounds Frequency` /
/// `Selection Sounds Frequency`. GemRB reads them in `Actor::CommandActor` and
/// `Actor::PlaySelectionSound`. PST adds one (`pstflags`); we are BG, so the
/// integers below are used as written. Lua 3 and 4 collapse to always on BG —
/// the 50%/80% rolls are `if (pstflags && …)` and do not run.
enum BarkFrequency: Int, CaseIterable, Sendable {
    case never = 1
    /// Command: one bark after selection (`playedCommandSound`). Selection: 20%.
    case oncePerSelection = 2
    /// Command 3+ and selection after `frequency > 2` is promoted to 5.
    case always = 5
}

enum BarkOutcome: Equatable, Sendable {
    case silent
    case common
    case rare
}

/// `Actor::CommandActor`'s frequency switch, BG only.
///
///     switch (CFGCache.commandSndFreq + pstflags) {
///       case 1: return;
///       case 2:
///         if (playedCommandSound) return;
///         playedCommandSound = true;
///         // fallthrough
///       case 3:
///         if (pstflags && RAND(1, 100) > 50) return;
///         break;
///       case 4:
///         if (pstflags && RAND(1, 100) > 80) return;
///         break;
///       default:;
///     }
///
/// No rare-command roll. BG2 spends rare-select slots as extra command lines
/// (`COMMAND_COUNT`), then `VerbalConstant` picks uniformly among them.
struct CommandSoundGate: Equatable, Sendable {
    var frequency: BarkFrequency
    private var playedCommandSound = false

    init(frequency: BarkFrequency = .oncePerSelection) {
        self.frequency = frequency
    }

    /// `PlaySelectionSound` starts with `playedCommandSound = false`.
    mutating func noteSelected() {
        playedCommandSound = false
    }

    mutating func resolve() -> BarkOutcome {
        switch frequency {
        case .never:
            return .silent
        case .oncePerSelection:
            if playedCommandSound { return .silent }
            playedCommandSound = true
            return .common
        case .always:
            return .common
        }
    }
}

/// `Actor::PlaySelectionSound`'s frequency switch, BG only.
///
///     unsigned int frequency = CFGCache.selectionSndFreq + pstflags;
///     if (force || (!pstflags && frequency > 2)) frequency = 5;
///     switch (frequency) {
///       case 1: return;
///       case 2: if (RAND(1, 100) > 20) return; break;
///       case 3: if (RAND(1, 100) > 50) return; break; // pst-only
///       case 4: if (RAND(1, 100) > 80) return; break; // pst-only
///       default:;
///     }
///     if (InParty && RAND(1, 100) <= rareSelectChance)
///
/// `rareSelectChance` is `RARE_SELECT_CHANCE` in `miscrule.2da` (5).
struct SelectionSoundGate: Equatable, Sendable {
    var frequency: BarkFrequency
    var rareChanceInHundred: Int

    init(frequency: BarkFrequency = .always, rareChanceInHundred: Int = 5) {
        self.frequency = frequency
        self.rareChanceInHundred = rareChanceInHundred
    }

    /// `roll` and `rareRoll` are 1...100, injected so the ladder is testable.
    func resolve(roll: Int, rareRoll: Int) -> BarkOutcome {
        switch frequency {
        case .never:
            return .silent
        case .oncePerSelection:
            if roll > 20 { return .silent }
        case .always:
            break
        }
        return rareRoll <= rareChanceInHundred ? .rare : .common
    }
}

/// `GetVerbalConstant(start, count)`: `RAND(0, count - 1)` among existing slots.
enum BarkPick {
    static func next(in pool: [String], roll: Int) -> String? {
        guard !pool.isEmpty else { return nil }
        let count = pool.count
        let remainder = roll.quotientAndRemainder(dividingBy: count).remainder
        let index = remainder >= 0 ? remainder : remainder + count
        return pool[index]
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
