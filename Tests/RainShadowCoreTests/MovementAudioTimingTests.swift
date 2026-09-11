import Testing
@testable import RainShadowCore

/// Footstep cadence, bark ladder, idle glance. See `MovementAudioTiming`.
struct MovementAudioTimingTests {
    // MARK: - Footsteps

    @Test func firstStepSoundsImmediately() {
        let cadence = FootstepCadence()
        #expect(cadence.allowsStep(at: 0, isWalking: true, silenced: false))
    }

    @Test func nextStepWaitsForTheClipToFinishNotForAFrame() {
        // BG gates on clip length, not on animation contact frames.
        var cadence = FootstepCadence()
        let long = FootstepCadence.strideInterval * 2
        cadence.noteStepStarted(at: 10.0, clipDuration: long)
        #expect(!cadence.allowsStep(at: 10.0 + long * 0.5, isWalking: true, silenced: false))
        #expect(!cadence.allowsStep(at: 10.0 + long - 0.001, isWalking: true, silenced: false))
        #expect(cadence.allowsStep(at: 10.0 + long, isWalking: true, silenced: false))
    }

    @Test func aShortClipStillCannotOutrunTheLegs() {
        // The one divergence from BG: its walk sounds were authored long enough
        // that clip length alone paced them. A tight sample here would otherwise
        // fire six times a second, so the stride floors it.
        var cadence = FootstepCadence()
        cadence.noteStepStarted(at: 10.0, clipDuration: 0.02)
        #expect(!cadence.allowsStep(at: 10.1, isWalking: true, silenced: false))
        #expect(cadence.allowsStep(
            at: 10.0 + FootstepCadence.strideInterval,
            isWalking: true,
            silenced: false
        ))
    }

    @Test func strideIntervalIsTwoStepsPerAuthoredCycle() {
        // 8 frames at 15Hz is a 0.533s cycle carrying two footfalls.
        #expect(abs(FootstepCadence.strideInterval - 8.0 / 15.0 / 2) < 1e-9)
    }

    @Test func stepsNeverOverlap() {
        // Walk for two seconds of logic ticks and count footfalls. With a 0.16s
        // clip nothing may ever start while the previous one is still sounding.
        var cadence = FootstepCadence()
        var starts: [Double] = []
        let clip = 0.26
        var now = 0.0
        for _ in 0..<Int(2.0 * LogicTickClock.ticksPerSecond) {
            if cadence.allowsStep(at: now, isWalking: true, silenced: false) {
                starts.append(now)
                cadence.noteStepStarted(at: now, clipDuration: clip)
            }
            now += LogicTickClock.tickDuration
        }
        #expect(starts.count > 1)
        for (previous, next) in zip(starts, starts.dropFirst()) {
            #expect(next - previous >= clip - 1e-9, "footsteps overlapped")
        }
    }

    @Test func standingAndSilencedActorsAreQuiet() {
        let cadence = FootstepCadence()
        #expect(!cadence.allowsStep(at: 5, isWalking: false, silenced: false))
        // Pause and dialogue both silence: BG checks DF_IN_DIALOG / DF_FREEZE_SCRIPTS
        // before it ever reaches the footstep call.
        #expect(!cadence.allowsStep(at: 5, isWalking: true, silenced: true))
    }

    @Test func stepCadenceLandsExactlyOnTheStrideWithTheShippedClips() {
        // The gate is sampled on logic ticks, so the achievable intervals are
        // multiples of 1/15s. The stride is exactly 4 of them, and the shipped
        // 0.26s clip stays under it — so footfalls land precisely on the gait
        // instead of rounding up to 5 ticks and drifting 25% slow.
        var cadence = FootstepCadence()
        var starts: [Double] = []
        var now = 0.0
        for _ in 0..<Int(2.0 * LogicTickClock.ticksPerSecond) {
            if cadence.allowsStep(at: now, isWalking: true, silenced: false) {
                starts.append(now)
                cadence.noteStepStarted(at: now, clipDuration: 0.26)
            }
            now += LogicTickClock.tickDuration
        }
        #expect(starts.count >= 6)
        for (previous, next) in zip(starts, starts.dropFirst()) {
            #expect(
                abs((next - previous) - FootstepCadence.strideInterval) < 1e-9,
                "footfall interval \(next - previous) is not the stride"
            )
        }
    }

    @Test func resetLetsTheNextWalkStartOnItsFirstStep() {
        var cadence = FootstepCadence()
        cadence.noteStepStarted(at: 10.0, clipDuration: 0.5)
        #expect(!cadence.allowsStep(at: 10.1, isWalking: true, silenced: false))
        cadence.reset()
        #expect(cadence.allowsStep(at: 10.1, isWalking: true, silenced: false))
    }

    // MARK: - Barks

    @Test func commandNeverIsSilent() {
        var gate = CommandSoundGate(frequency: .never)
        #expect(gate.resolve() == .silent)
        #expect(gate.resolve() == .silent)
    }

    @Test func commandOncePerSelectionBarksOnceThenRearmsOnReselect() {
        // `Actor::CommandActor` case 2: `playedCommandSound` gates until
        // `PlaySelectionSound` clears it.
        var gate = CommandSoundGate(frequency: .oncePerSelection)
        #expect(gate.resolve() == .common)
        #expect(gate.resolve() == .silent)
        #expect(gate.resolve() == .silent)
        gate.noteSelected()
        #expect(gate.resolve() == .common)
    }

    @Test func commandAlwaysIsAlways() {
        // BG command 3+ has no roll; the 50%/80% cases are `if (pstflags && …)`.
        var gate = CommandSoundGate(frequency: .always)
        #expect(gate.resolve() == .common)
        #expect(gate.resolve() == .common)
    }

    @Test func commandHasNoRareOutcome() {
        var gate = CommandSoundGate(frequency: .always)
        #expect(gate.resolve() != .rare)
        var once = CommandSoundGate(frequency: .oncePerSelection)
        #expect(once.resolve() != .rare)
    }

    @Test func selectionNeverIsSilentAtEveryRoll() {
        let gate = SelectionSoundGate(frequency: .never, rareChanceInHundred: 100)
        for roll in [1, 20, 21, 100] {
            #expect(gate.resolve(roll: roll, rareRoll: 1) == .silent)
        }
    }

    @Test func selectionSeldomIsTwentyPercent() {
        // `PlaySelectionSound` case 2: `if (RAND(1, 100) > 20) return;`
        let gate = SelectionSoundGate(frequency: .oncePerSelection, rareChanceInHundred: 5)
        #expect(gate.resolve(roll: 20, rareRoll: 100) == .common)
        #expect(gate.resolve(roll: 21, rareRoll: 100) == .silent)
        #expect(gate.resolve(roll: 1, rareRoll: 5) == .rare)
        #expect(gate.resolve(roll: 21, rareRoll: 1) == .silent)
    }

    @Test func selectionAlwaysPlaysAndRaresAtFivePercent() {
        // BG promotes selection frequency > 2 to 5. `RARE_SELECT_CHANCE` is 5.
        let gate = SelectionSoundGate(frequency: .always, rareChanceInHundred: 5)
        #expect(gate.resolve(roll: 100, rareRoll: 5) == .rare)
        #expect(gate.resolve(roll: 100, rareRoll: 6) == .common)
        #expect(gate.resolve(roll: 1, rareRoll: 100) == .common)
    }

    @Test func aSilentSelectionLadderNeverReachesTheRareRoll() {
        let gate = SelectionSoundGate(frequency: .never, rareChanceInHundred: 100)
        #expect(gate.resolve(roll: 1, rareRoll: 1) == .silent)
    }

    @Test func verbalConstantPicksUniformlyAmongSlots() {
        let pool = ["a", "b", "c"]
        #expect(BarkPick.next(in: pool, roll: 0) == "a")
        #expect(BarkPick.next(in: pool, roll: 1) == "b")
        #expect(BarkPick.next(in: pool, roll: 2) == "c")
        #expect(BarkPick.next(in: pool, roll: 3) == "a")
        #expect(BarkPick.next(in: ["only"], roll: 7) == "only")
        #expect(BarkPick.next(in: [], roll: 0) == nil)
    }

    // MARK: - Idle behaviour

    @Test func scriptsRunOnASixteenTickStride() {
        var clock = IdleBehaviourClock(phase: 0)
        var hits = 0
        for _ in 0..<160 where clock.advanceTickRunsScript() { hits += 1 }
        #expect(hits == 10)
    }

    @Test func actorsAreStaggeredAgainstEachOther() {
        // BG staggers by globalID % 16 so a crowd does not glance in unison.
        var a = IdleBehaviourClock(phase: 0)
        var b = IdleBehaviourClock(phase: 7)
        var sameTick = 0
        for _ in 0..<160 {
            let ra = a.advanceTickRunsScript()
            let rb = b.advanceTickRunsScript()
            if ra && rb { sameTick += 1 }
        }
        #expect(sameTick == 0)
    }

    @Test func headTurnIsOneChanceInTwentyFive() {
        #expect(IdleBehaviourClock.headTurnOdds == 25)
        #expect(IdleBehaviourClock.rollWantsHeadTurn(0))
        #expect(!IdleBehaviourClock.rollWantsHeadTurn(1))
        #expect(!IdleBehaviourClock.rollWantsHeadTurn(24))

        // The number that actually matters is the resulting pace: a glance about
        // every 27 seconds, which is noticeable without being a fidget.
        let secondsPerScriptPass =
            Double(IdleBehaviourClock.scriptStrideTicks) / LogicTickClock.ticksPerSecond
        let secondsPerGlance = secondsPerScriptPass * Double(IdleBehaviourClock.headTurnOdds)
        #expect(secondsPerGlance > 25 && secondsPerGlance < 30)
    }
}
