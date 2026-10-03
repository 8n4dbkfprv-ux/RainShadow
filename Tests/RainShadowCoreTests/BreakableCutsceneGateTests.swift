import Testing
@testable import RainShadowCore

struct BreakableCutsceneGateTests {
    @Test func breakingRequiresExplicitOptInAndHasNoGracePeriod() {
        var gate = BreakableCutsceneGate()
        gate.begin(at: 10)
        #expect(!gate.canSkip(at: 100))
        gate.isBreakable = true
        #expect(gate.canSkip(at: 10))
        gate.isBreakable = false
        #expect(!gate.canSkip(at: 10))
    }

    @Test func completionIsSingleFireAndRearmingClearsBrokenAndBreakable() {
        var gate = BreakableCutsceneGate()
        gate.begin(at: 0, breakable: true)
        gate.markBroken()
        #expect(gate.wasBroken && !gate.canSkip(at: 0))
        let first = gate.markCompleted(reason: .skipped)
        let second = gate.markCompleted()
        #expect(first && !second)
        gate.begin(at: 5)
        #expect(!gate.wasBroken && !gate.isBreakable)
        let natural = gate.markCompleted()
        #expect(natural)
        #expect(!gate.wasBroken)
        gate.reset()
        #expect(!gate.isActive && !gate.isCompleted)
    }
}
