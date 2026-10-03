import CoreGraphics
import Testing
@testable import RainShadowCore

/// Expectations are taken from the pinned upstream functions quoted in
/// Documentation/CinematicParityAuditOct02.md, including non-blocking actions.
struct CutsceneRunnerTests {
    @Test func waitsUseFifteenHz() {
        #expect(CutsceneBeat.seconds(1).ticks == 15)
        #expect(CutsceneBeat.ticks(15).seconds == 1)
        #expect(CutsceneBeat.seconds(0).ticks == 0)
    }

    @Test func duplicateSubjectsAppendInScriptOrder() {
        var runner = CutsceneRunner()
        let start = runner.begin(Cutscene(id: "repeat", tracks: [
            CutsceneTrack(.world, [.wait(.ticks(2)), .setFlag("first")]),
            CutsceneTrack(.world, [.setFlag("second")])
        ]), at: 0)
        #expect(start.commands == [CutsceneCommand(.world, .wait(.ticks(2)))])
        #expect(runner.advance(ticks: 2).commands == [
            CutsceneCommand(.world, .setFlag("first")), CutsceneCommand(.world, .setFlag("second"))
        ])
        #expect(!runner.isPlaying)
    }

    @Test func aSubjectDrainsItsImmediateActionsBeforeTheNextSubject() {
        var runner = CutsceneRunner()
        let step = runner.begin(Cutscene(id: "order", tracks: [
            CutsceneTrack(.world, [.setFlag("first"), .setFlag("second")]),
            CutsceneTrack(.actor(.detective), [.setFlag("third")])
        ]), at: 0)
        #expect(step.commands.map(\.cue) == [.setFlag("first"), .setFlag("second"), .setFlag("third")])
    }

    @Test func bulkAdvancePreservesEveryIntermediateDeadline() {
        let scene = Cutscene(id: "waits", tracks: [
            CutsceneTrack(.world, [.wait(.ticks(2)), .setFlag("a"), .wait(.ticks(3)), .setFlag("b")])
        ])
        var bulk = CutsceneRunner(), singles = CutsceneRunner()
        _ = bulk.begin(scene, at: 0)
        _ = singles.begin(scene, at: 0)
        let result = bulk.advance(ticks: 5)
        var commands: [CutsceneCommand] = []
        for _ in 0..<5 { commands += singles.advance(ticks: 1).commands }
        #expect(result.commands == commands)
        #expect(result.completion == .natural)
        #expect(bulk == singles)
    }

    @Test func walkBlocksOnlyItsActor() {
        var runner = CutsceneRunner()
        let start = runner.begin(Cutscene(id: "walk", tracks: [
            CutsceneTrack(.actor(.client), [.moveToPoint(CGPoint(x: 100, y: 20)), .setFlag("arrived")]),
            CutsceneTrack(.world, [.setFlag("parallel")])
        ]), at: 0)
        #expect(start.commands.contains(CutsceneCommand(.world, .setFlag("parallel"))))
        #expect(runner.advance(ticks: 100).commands.isEmpty)
        let end = runner.noteCompleted(.actor(.client))
        #expect(end.commands == [CutsceneCommand(.actor(.client), .setFlag("arrived"))])
        #expect(end.completion == .natural)
        #expect(runner.noteCompleted(.actor(.client)).isEmpty)
    }

    @Test func ordinaryCameraMovesAndHeadTextDoNotBlock() {
        let cues: [CutsceneCue] = [
            .moveViewPoint(CGPoint(x: 100, y: 200), .slow),
            .moveViewObject(.client, .fast),
            .displayStringHead(stringKey: "line", .seconds(8)), .setFlag("immediate")
        ]
        var runner = CutsceneRunner()
        let step = runner.begin(Cutscene(id: "instant", tracks: [CutsceneTrack(.world, cues)]), at: 0)
        #expect(step.commands.map(\.cue) == cues)
        #expect(step.completion == .natural)
    }

    @Test func untilDoneCameraActionIsDistinct() {
        var runner = CutsceneRunner()
        _ = runner.begin(Cutscene(id: "scroll", tracks: [CutsceneTrack(.world, [
            .moveViewPointUntilDone(CGPoint(x: 100, y: 200), .slow), .setFlag("landed")
        ])]), at: 0)
        #expect(runner.advance(ticks: 500).commands.isEmpty)
        #expect(runner.noteCompleted(.world).completion == .natural)
    }

    @Test func faceHoldsForOneUpdate() {
        var runner = CutsceneRunner()
        let step = runner.begin(Cutscene(id: "face", tracks: [CutsceneTrack(.actor(.detective), [
            .face(.south), .faceObject(.client), .setFlag("done")
        ])]), at: 0)
        #expect(step.commands.map(\.cue) == [.face(.south)])
        #expect(runner.advance(ticks: 1).commands.map(\.cue) == [.faceObject(.client)])
        #expect(runner.advance(ticks: 1).completion == .natural)
    }

    @Test func overrideReleasesIssuerAndSerializesTargetWork() {
        var runner = CutsceneRunner()
        let start = runner.begin(Cutscene(id: "override", tracks: [CutsceneTrack(.world, [
            .actionOverride(.client, .wait(.ticks(2))),
            .actionOverride(.client, .setFlag("target")), .setFlag("issuer")
        ])]), at: 0)
        #expect(start.commands.contains(CutsceneCommand(.world, .setFlag("issuer"))))
        #expect(!start.commands.contains(CutsceneCommand(.actor(.client), .setFlag("target"))))
        #expect(runner.advance(ticks: 1).commands.isEmpty)
        #expect(runner.advance(ticks: 1).commands.contains(CutsceneCommand(.actor(.client), .setFlag("target"))))
        #expect(!runner.isPlaying)
    }

    @Test func overrideClearsOrdinaryTargetActionsAndKeepsOtherOverrides() {
        var runner = CutsceneRunner()
        _ = runner.begin(Cutscene(id: "clear", tracks: [
            CutsceneTrack(.actor(.client), [.moveToPoint(.zero), .setFlag("discard")]),
            CutsceneTrack(.world, [
                .wait(.ticks(1)), .actionOverride(.client, .wait(.ticks(3))),
                .actionOverride(.client, .setFlag("keep"))
            ])
        ]), at: 0)
        let override = runner.advance(ticks: 1)
        #expect(override.commands.contains(CutsceneCommand(.actor(.client), .clearActions)))
        #expect(runner.noteCompleted(.actor(.client)).isEmpty)
        let end = runner.advance(ticks: 3)
        #expect(end.commands == [CutsceneCommand(.actor(.client), .setFlag("keep"))])
        #expect(end.completion == .natural)
    }

    @Test func nestedOverridesResolveThroughTargetQueues() {
        var runner = CutsceneRunner()
        let step = runner.begin(Cutscene(id: "nested", tracks: [CutsceneTrack(.world, [
            .actionOverride(.client, .actionOverride(.detective, .setFlag("nested")))
        ])]), at: 0)
        #expect(step.commands.contains(CutsceneCommand(.actor(.detective), .setFlag("nested"))))
        #expect(step.completion == .natural)
    }

    @Test func animationWaitReleasesOnStanceCompletionOrEngineRoundLimit() {
        let scene = Cutscene(id: "animation", tracks: [CutsceneTrack(.actor(.detective), [
            .playSequence(.getUp), .waitAnimation(.getUp), .setFlag("done")
        ])])
        var runner = CutsceneRunner()
        let start = runner.begin(scene, at: 0)
        #expect(start.commands.map(\.cue) == [.playSequence(.getUp), .waitAnimation(.getUp)])
        #expect(runner.advance(ticks: 90).completion == nil)
        #expect(runner.advance(ticks: 1).completion == .natural)
        _ = runner.begin(scene, at: 0)
        #expect(runner.noteAnimationCompleted(.actor(.detective), sequence: .getUp).completion == .natural)
        #expect(runner.noteAnimationCompleted(.actor(.detective), sequence: .getUp).isEmpty)
    }

    @Test func fadeSuspendsAllScriptQueuesAndTheirWaitClocks() {
        var runner = CutsceneRunner()
        _ = runner.begin(Cutscene(id: "fade", tracks: [
            CutsceneTrack(.world, [.wait(.ticks(3)), .setFlag("world")]),
            CutsceneTrack(.actor(.detective), [.fadeToColor(.black, .ticks(2)), .setFlag("faded")])
        ]), at: 0)
        #expect(runner.isFading)
        #expect(runner.advance(ticks: 1).commands.isEmpty)
        let faded = runner.advance(ticks: 1)
        #expect(!runner.isFading)
        #expect(faded.commands == [CutsceneCommand(.actor(.detective), .setFlag("faded"))])
        #expect(runner.advance(ticks: 1).commands.isEmpty)
        #expect(runner.advance(ticks: 1).commands == [CutsceneCommand(.world, .setFlag("world"))])
    }

    @Test func runtimeBreakabilityTogglesWithoutGraceAndSkipDoesNotReplayActions() {
        var runner = CutsceneRunner()
        _ = runner.begin(Cutscene(id: "skip", tracks: [CutsceneTrack(.world, [
            .wait(.ticks(1)), .setCutsceneBreakable(true),
            .wait(.ticks(1)), .setCutsceneBreakable(false),
            .wait(.ticks(1)), .setFlag("must-not-replay")
        ])]), at: 10)
        #expect(runner.skip(at: 10).isEmpty)
        _ = runner.advance(ticks: 1)
        #expect(runner.canSkip(at: 10))
        let broken = runner.skip(at: 10)
        #expect(broken.completion == .skipped)
        #expect(broken.commands == [CutsceneCommand(.world, .setCutsceneMode(false))])
        #expect(runner.wasBroken && runner.skip(at: 10).isEmpty)
        #expect(runner.advance(ticks: 99).isEmpty)

        _ = runner.begin(Cutscene(id: "toggle", tracks: [CutsceneTrack(.world, [
            .setCutsceneBreakable(true), .wait(.ticks(1)),
            .setCutsceneBreakable(false), .wait(.ticks(2))
        ])]), at: 0)
        _ = runner.advance(ticks: 1)
        #expect(!runner.canSkip(at: 100))
    }

    @Test func recoveryRunsItsActualWaitsAndActionsInsteadOfTerminalForms() {
        var runner = CutsceneRunner()
        _ = runner.begin(Cutscene(id: "recovery", isBreakable: true, tracks: [
            CutsceneTrack(.actor(.client), [.moveToPoint(CGPoint(x: 5, y: 9)), .setFlag("discard")])
        ], skipTracks: [CutsceneTrack(.world, [.wait(.ticks(3)), .setFlag("recover")])]), at: 0)
        let broken = runner.skip(at: 0)
        #expect(broken.completion == nil)
        #expect(broken.commands.contains(CutsceneCommand(.actor(.client), .clearActions)))
        #expect(!broken.commands.contains { if case .jumpToPoint = $0.cue { return true }; return false })
        #expect(runner.advance(ticks: 2).isEmpty)
        let recovered = runner.advance(ticks: 1)
        #expect(recovered.commands == [CutsceneCommand(.world, .setFlag("recover"))])
        #expect(recovered.completion == .skipped)
    }

}

struct CutsceneViewportTests {
    @Test func scrollIdsAreTwiceTheirValuePerTick() {
        #expect(ScrollSpeed.allCases.map(\.pointsPerTick) == [0, 2, 4, 6, 8])
        #expect(ScrollSpeed.veryFast.pointsPerSecond == 120)
    }

    @Test func scrollMovesInsteadOfJumpingAndUsesProjectedDistance() {
        var rail = CutsceneViewport(position: .zero)
        rail.move(to: CGPoint(x: 0, y: 40), speed: .standard)
        #expect(rail.position == .zero)
        rail.advance()
        #expect(rail.position == CGPoint(x: 0, y: 4))
        rail.advance(ticks: 9)
        #expect(rail.position == CGPoint(x: 0, y: 40))
        #expect(!rail.isMoving)
    }

    @Test func diagonalScrollUsesIntegerEngineStep() {
        var rail = CutsceneViewport(position: .zero)
        rail.move(to: CGPoint(x: 30, y: 40), speed: .veryFast)
        rail.advance()
        #expect(rail.position == CGPoint(x: 4, y: 6)) // int(0.16 * (30,40))
    }

    @Test func instantAndBoundaryStopsNeedNoTimer() {
        var rail = CutsceneViewport(position: .zero)
        rail.move(to: CGPoint(x: 100, y: 50), speed: .instant)
        #expect(!rail.isMoving)
        #expect(rail.position == CGPoint(x: 100, y: 50))
        rail.move(to: CGPoint(x: 500, y: 50), speed: .slow)
        rail.advance()
        rail.reconcile(clamped: CGPoint(x: 100, y: 50), previous: CGPoint(x: 100, y: 50))
        #expect(!rail.isMoving)
    }
}

struct CutsceneFadeTimerTests {
    @Test func zeroReusesDefaultOrLastDurationAndAlphaTruncates() {
        var timer = CutsceneFadeTimer()
        timer.fadeTo(ticks: 0)
        timer.advance()
        #expect(timer.alpha == 12 && timer.isFading)
        for _ in 1..<20 { timer.advance() }
        #expect(timer.alpha == 255 && !timer.isFading)
        timer.fadeFrom(ticks: 3)
        timer.advance()
        #expect(timer.alpha == 170)
        timer.advance()
        #expect(timer.alpha == 85)
        timer.advance()
        #expect(timer.alpha == 0 && !timer.isFading)
        timer.fadeTo(ticks: 0)
        timer.advance()
        #expect(timer.alpha == 85 && timer.lastDuration == 3)
    }

    @Test func blackResetsAfter150PostFadeUpdatesWithoutBlockingScripts() {
        var runner = CutsceneRunner()
        _ = runner.begin(Cutscene(id: "black", tracks: [CutsceneTrack(.world, [
            .fadeToColor(.black, .ticks(2))
        ])]), at: 0)
        #expect(runner.advance(ticks: 2).completion == .natural)
        #expect(runner.fade.alpha == 255 && !runner.isFading)
        _ = runner.advance(ticks: 149)
        #expect(runner.fade.alpha == 255)
        _ = runner.advance(ticks: 1)
        #expect(runner.fade.alpha == 0)
    }
}
