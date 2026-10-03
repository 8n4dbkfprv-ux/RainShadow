import Testing
@testable import RainShadowCore

struct BreakableCutsceneGateTests {
    @Test func graceWindowBlocksSkipThenAllowsIt() {
        var gate = BreakableCutsceneGate(graceSeconds: 1.0)
        gate.begin(at: 10.0)
        #expect(gate.isActive)
        #expect(!gate.isCompleted)
        #expect(!gate.canSkip(at: 10.0))
        #expect(!gate.canSkip(at: 10.99))
        #expect(gate.canSkip(at: 11.0))
        #expect(gate.canSkip(at: 12.5))
    }

    @Test func markCompletedIsSingleFireForNaturalAndSkip() {
        var gate = BreakableCutsceneGate(graceSeconds: 0.5)
        gate.begin(at: 0)
        let first = gate.markCompleted()
        #expect(first)
        #expect(gate.isCompleted)
        #expect(!gate.isActive)
        let second = gate.markCompleted()
        #expect(!second, "Second complete must no-op (skip + natural share one path)")
        #expect(!gate.canSkip(at: 100))
    }

    @Test func resetClearsCompletionForReuse() {
        var gate = BreakableCutsceneGate()
        gate.begin(at: 1)
        let first = gate.markCompleted()
        #expect(first)
        gate.reset()
        #expect(!gate.isActive)
        #expect(!gate.isCompleted)
        gate.begin(at: 5, graceSeconds: 0.25)
        #expect(gate.canSkip(at: 5.25))
        let second = gate.markCompleted()
        #expect(second)
    }

    @Test func defaultGraceMatchesExteriorOpening() {
        #expect(BreakableCutsceneGate.defaultGraceSeconds == 1.0)
    }

    /// BG:EE `SetCutSceneBreakable(0)`: breakability is a per-sequence content
    /// flag, so a non-breakable gate refuses skip however long it has run.
    @Test func nonBreakableSequenceNeverAcceptsSkip() {
        var gate = BreakableCutsceneGate(graceSeconds: 0.5)
        gate.begin(at: 0, breakable: false)
        #expect(gate.isActive)
        #expect(!gate.canSkip(at: 0.5))
        #expect(!gate.canSkip(at: 1_000))
        // It still completes naturally, exactly once.
        let first = gate.markCompleted()
        #expect(first)
        let second = gate.markCompleted()
        #expect(!second)
    }

    /// BG:EE `CutSceneBroken()` — true only when the user terminated it.
    @Test func brokenFlagTracksCompletionReason() {
        var gate = BreakableCutsceneGate()
        gate.begin(at: 0)
        #expect(!gate.wasBroken, "Nothing is broken while the cutscene is still running")
        gate.markCompleted(reason: .skipped)
        #expect(gate.wasBroken)

        gate.begin(at: 10)
        #expect(!gate.wasBroken, "Re-arming clears the previous run's broken flag")
        gate.markCompleted(reason: .natural)
        #expect(!gate.wasBroken)

        gate.reset()
        #expect(!gate.wasBroken)
    }

    /// Re-arming must restore breakability: a gate previously armed non-breakable
    /// would otherwise silently make the next sequence unskippable.
    @Test func rearmingRestoresBreakability() {
        var gate = BreakableCutsceneGate(graceSeconds: 0.25)
        gate.begin(at: 0, breakable: false)
        gate.markCompleted()
        gate.begin(at: 5)
        #expect(gate.isBreakable)
        #expect(gate.canSkip(at: 5.25))
    }

    /// Skip and natural finish differ in presentation timing only.
    @Test func chromeDurationCutsOnlyForBrokenCutscenes() {
        #expect(CutsceneCompletionReason.natural.chromeDuration(0.3) == 0.3)
        #expect(CutsceneCompletionReason.skipped.chromeDuration(0.3) == 0)
        #expect(CutsceneCompletionReason.skipped.chromeDuration(0) == 0)
    }
}
