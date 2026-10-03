import CoreGraphics
import Foundation
import Testing
@testable import RainShadowCore

/// The cue runner is the first cutscene machinery in the project that can be
/// tested without a render loop. Everything these cases pin used to be reachable
/// only by grepping `DetectiveOfficeScene.swift` as text.
struct CutsceneRunnerTests {

    private let doorway = CGPoint(x: 100, y: 100)
    private let framing = CGPoint(x: 400, y: 220)

    // MARK: - Beats

    /// `SmallWait(n)` is n AI updates and BG's AI updates run at 15 Hz — the same
    /// clock `LogicTickClock` already implements for locomotion.
    @Test func smallWaitAndWaitShareTheEngineTick() {
        #expect(CutsceneBeat.ticks(15).ticks == 15)
        #expect(CutsceneBeat.seconds(1.0).ticks == 15)
        #expect(CutsceneBeat.seconds(2.0).ticks == 30)
        #expect(CutsceneBeat.ticks(15).seconds == 1.0)
        #expect(LogicTickClock.ticksPerSecond == 15)
    }

    /// A beat authored shorter than one tick must still cost a tick. Rounding it
    /// to zero would silently delete an authored pause.
    @Test func subTickBeatsRoundUpRatherThanVanishing() {
        #expect(CutsceneBeat.seconds(0.01).ticks == 1)
        #expect(CutsceneBeat.seconds(0).ticks == 0)
        #expect(CutsceneBeat.ticks(-3).ticks == 0)
    }

    /// IESDP records VERY_FAST as "equivalent to normal walking speed".
    @Test func veryFastScrollMatchesTheWalkRate() {
        #expect(ScrollSpeed.veryFast.pointsPerSecond == ActorLocomotionPacing.walkSpeed)
        #expect(ScrollSpeed.instant.pointsPerSecond == nil)

        let ordered: [ScrollSpeed] = [.slow, .standard, .fast, .veryFast]
        let rates = ordered.compactMap(\.pointsPerSecond)
        #expect(rates.count == 4)
        #expect(rates == rates.sorted(), "scroll.ids is ordered slowest to fastest")
    }

    @Test func scrollDurationIsDistanceOverRate() {
        let speed = ScrollSpeed.veryFast
        let rate = try! #require(speed.pointsPerSecond)
        let beat = speed.beat(forDistance: rate * 2)
        #expect(abs(beat.seconds - 2.0) < LogicTickClock.tickDuration)
        #expect(ScrollSpeed.instant.beat(forDistance: 500) == .instant)
    }

    // MARK: - Track semantics

    /// The BG rule this whole system exists for: separate `CutSceneId` blocks
    /// play at the same time. Before the runner there was no way to say
    /// "he stands up while she walks in" except overlapping callbacks.
    @Test func tracksWithDifferentSubjectsStartTogether() {
        var runner = CutsceneRunner()
        let step = runner.begin(
            Cutscene(id: "parallel", tracks: [
                CutsceneTrack(.actor(.client), [.followPath([doorway, framing], .entering)]),
                CutsceneTrack(.actor(.detective), [.standUp]),
                CutsceneTrack(.chrome, [.letterbox(true), .wait(.seconds(4))])
            ]),
            at: 0
        )

        #expect(step.commands.contains(CutsceneCommand(.actor(.client), .followPath([doorway, framing], .entering))))
        #expect(step.commands.contains(CutsceneCommand(.actor(.detective), .standUp)))
        #expect(step.commands.contains(CutsceneCommand(.chrome, .letterbox(true))))
        #expect(step.completion == nil)
    }

    /// Cues inside one track block each other, exactly as actions do inside one
    /// `CutSceneId` block.
    @Test func cuesWithinATrackAreSequential() {
        var runner = CutsceneRunner()
        let step = runner.begin(
            Cutscene(id: "sequential", tracks: [
                CutsceneTrack(.camera, [
                    .wait(.seconds(1)),
                    .moveViewPoint(framing, .standard)
                ])
            ]),
            at: 0
        )
        #expect(step.commands == [CutsceneCommand(.camera, .wait(.seconds(1)))])

        #expect(runner.advance(ticks: 14).commands.isEmpty, "One tick short of the beat")
        let due = runner.advance(ticks: 1)
        #expect(due.commands == [CutsceneCommand(.camera, .moveViewPoint(framing, .standard))])
    }

    /// A run of zero-duration cues lands in one step rather than one per tick.
    @Test func instantCuesCollapseIntoASingleStep() {
        var runner = CutsceneRunner()
        let step = runner.begin(
            Cutscene(id: "instant", tracks: [
                CutsceneTrack(.world, [
                    .setDoor(.officeEntrance, open: true),
                    .setFlag("office.introPlayed")
                ])
            ]),
            at: 0
        )
        #expect(step.commands.count == 2)
        #expect(step.completion == .natural, "Nothing left to wait for")
    }

    /// `MoveToPoint` blocks until arrival; so does ours.
    @Test func openEndedCuesHoldTheirTrackUntilReported() {
        var runner = CutsceneRunner()
        _ = runner.begin(
            Cutscene(id: "walk", tracks: [
                CutsceneTrack(.actor(.client), [.followPath([doorway, framing], .entering), .face(.south)])
            ]),
            at: 0
        )
        #expect(runner.advance(ticks: 600).commands.isEmpty, "Time alone cannot end a walk")

        let arrived = runner.noteCompleted(.actor(.client))
        #expect(arrived.commands == [CutsceneCommand(.actor(.client), .face(.south))])
        #expect(arrived.completion == .natural)
    }

    /// A camera scroll is open-ended for the same reason: its duration is
    /// distance over rate, and only the director knows the distance.
    @Test func cameraScrollBlocksUnlessInstant() {
        #expect(CutsceneCue.moveViewPoint(.zero, .slow).isOpenEnded)
        #expect(!CutsceneCue.moveViewPoint(.zero, .instant).isOpenEnded)
        #expect(CutsceneCue.moveViewObject(.client, .veryFast).isOpenEnded)
    }

    /// The cutscene ends when the *last* track does, not the first.
    @Test func completionWaitsForEveryTrack() {
        var runner = CutsceneRunner()
        _ = runner.begin(
            Cutscene(id: "ragged", tracks: [
                CutsceneTrack(.chrome, [.wait(.ticks(2))]),
                CutsceneTrack(.actor(.client), [.followPath([doorway], .entering)])
            ]),
            at: 0
        )
        #expect(runner.advance(ticks: 2).completion == nil, "Client track still walking")
        #expect(runner.noteCompleted(.actor(.client)).completion == .natural)
        #expect(!runner.isPlaying)
    }

    // MARK: - Skip

    @Test func graceWindowGovernsSkip() {
        var runner = CutsceneRunner()
        _ = runner.begin(
            Cutscene(id: "graced", graceSeconds: 1.0, tracks: [
                CutsceneTrack(.chrome, [.wait(.seconds(10))])
            ]),
            at: 10
        )
        #expect(!runner.canSkip(at: 10.5))
        #expect(runner.canSkip(at: 11.0))
    }

    /// `SetCutSceneBreakable(0)`: breakability is a per-sequence content flag.
    @Test func nonBreakableCutsceneRefusesSkipButStillCompletes() {
        var runner = CutsceneRunner()
        _ = runner.begin(
            Cutscene(id: "locked", isBreakable: false, tracks: [
                CutsceneTrack(.chrome, [.wait(.ticks(1))])
            ]),
            at: 0
        )
        #expect(!runner.canSkip(at: 1_000))
        #expect(runner.skip(at: 1_000).isEmpty)
        #expect(runner.advance(ticks: 1).completion == .natural)
    }

    /// Skip re-applies the in-flight cue too. A half-walked path still owes its
    /// endpoint, or the actor is left standing in the doorway.
    @Test func skipTerminatesTheInFlightCueAsWellAsTheQueue() {
        var runner = CutsceneRunner()
        _ = runner.begin(
            Cutscene(id: "broken", graceSeconds: 0, tracks: [
                CutsceneTrack(.actor(.client), [
                    .followPath([doorway, framing], .entering),
                    .face(.south)
                ])
            ]),
            at: 0
        )
        let step = runner.skip(at: 1)
        #expect(step.commands == [
            CutsceneCommand(.actor(.client), .jumpToPoint(framing, .entering)),
            CutsceneCommand(.actor(.client), .face(.south))
        ])
        #expect(step.completion == .skipped)
        #expect(runner.wasBroken, "CutSceneBroken()")
    }

    /// The reason travels with the step, so nothing has to latch it on the scene
    /// and read it back out — the seam the roadmap records at §6.
    @Test func completionReasonArrivesWithTheStep() {
        var natural = CutsceneRunner()
        _ = natural.begin(Cutscene(id: "a", tracks: [CutsceneTrack(.chrome, [.wait(.ticks(1))])]), at: 0)
        #expect(natural.advance(ticks: 1).completion == .natural)
        #expect(!natural.wasBroken)

        var broken = CutsceneRunner()
        _ = broken.begin(
            Cutscene(id: "b", graceSeconds: 0, tracks: [CutsceneTrack(.chrome, [.wait(.seconds(30))])]),
            at: 0
        )
        #expect(broken.skip(at: 1).completion == .skipped)
        #expect(broken.wasBroken)
    }

    @Test func completionFiresExactlyOnce() {
        var runner = CutsceneRunner()
        _ = runner.begin(
            Cutscene(id: "single", graceSeconds: 0, tracks: [
                CutsceneTrack(.chrome, [.wait(.ticks(1))])
            ]),
            at: 0
        )
        #expect(runner.advance(ticks: 1).completion == .natural)
        #expect(runner.advance(ticks: 1).isEmpty)
        #expect(runner.skip(at: 5).isEmpty, "A finished cutscene cannot be broken")
    }

    // MARK: - Terminal forms

    @Test func terminalFormsCollapseDurationWithoutChangingEffect() {
        #expect(CutsceneCue.wait(.seconds(9)).terminal == .wait(.instant))
        #expect(CutsceneCue.moveViewPoint(framing, .slow).terminal == .moveViewPoint(framing, .instant))
        #expect(CutsceneCue.moveViewObject(.client, .fast).terminal == .moveViewObject(.client, .instant))
        #expect(CutsceneCue.fadeToColor(.black, .seconds(2)).terminal == .fadeToColor(.black, .instant))
        #expect(CutsceneCue.cameraScale(0.8, .seconds(3)).terminal == .cameraScale(0.8, .instant))
        #expect(CutsceneCue.moveToPoint(framing).terminal == .jumpToPoint(framing, .plain))
        // The endpoint alone is not the end state — an arrival ends visible,
        // a departure ends hidden past the door.
        #expect(CutsceneCue.followPath([doorway, framing], .entering).terminal
            == .jumpToPoint(framing, .entering))
        #expect(CutsceneCue.followPath([doorway, framing], .leaving).terminal
            == .jumpToPoint(framing, .leaving))

        // State-bearing cues are their own terminal form — a skip must still open
        // the door, set the flag, and resume the graph.
        #expect(CutsceneCue.setDoor(.officeEntrance, open: true).terminal
            == .setDoor(.officeEntrance, open: true))
        #expect(CutsceneCue.setFlag("f").terminal == .setFlag("f"))
        #expect(CutsceneCue.resumeDialogue(nodeID: "n").terminal == .resumeDialogue(nodeID: "n"))
        #expect(CutsceneCue.letterbox(false).terminal == .letterbox(false))
        #expect(CutsceneCue.setCutsceneMode(false).terminal == .setCutsceneMode(false))
    }

    /// A line nobody had time to read should be dropped, not flashed for a frame.
    @Test func overheadTextIsDroppedByASkip() {
        #expect(CutsceneCue.displayStringHead(stringKey: "k", .seconds(2)).terminal == .wait(.instant))
    }

    // MARK: - The invariant

    /// The frozen rule from `CinematicSystemRoadmap` §9: skip and natural
    /// completion apply the same terminal state.
    ///
    /// Asserted here by construction rather than by inspection — for every tick
    /// at which the cutscene could be broken, the union of what was already
    /// played and what the skip emits must carry the same state-bearing cues as
    /// playing it out. That covers cues authored *after* this test was written,
    /// which is the failure mode the shipped hand-written skip path cannot rule out.
    @Test(arguments: 0..<40)
    func skipAtAnyTickReachesTheSameTerminalStateAsPlayingOut(breakTick: Int) {
        let cutscene = Self.representativeCutscene

        var played = CutsceneRunner()
        var naturalCommands = played.begin(cutscene, at: 0).commands
        for _ in 0..<120 {
            naturalCommands += played.advance(ticks: 1).commands
            for subject in cutscene.tracks.map(\.subject) {
                naturalCommands += played.noteCompleted(subject).commands
            }
            if !played.isPlaying { break }
        }
        #expect(!played.isPlaying, "Reference run must finish")

        var interrupted = CutsceneRunner()
        var brokenCommands = interrupted.begin(cutscene, at: 0).commands
        for _ in 0..<breakTick where interrupted.isPlaying {
            brokenCommands += interrupted.advance(ticks: 1).commands
        }
        brokenCommands += interrupted.skip(at: 1_000).commands

        #expect(
            Self.terminalState(of: brokenCommands) == Self.terminalState(of: naturalCommands),
            "Breaking at tick \(breakTick) diverged from natural completion"
        )
    }

    /// Every state-bearing cue in a run, reduced to its final value per subject.
    /// Presentation-only cues (waits, scroll rates, overhead text) are excluded —
    /// those are the *only* things a skip is allowed to differ on.
    private static func terminalState(of commands: [CutsceneCommand]) -> [String: String] {
        var state: [String: String] = [:]
        for command in commands {
            // An override is credited to the actor it retargets, not the track
            // that issued it — that is the whole point of the cue.
            var subject = command.subject
            var cue = command.cue
            while case .actionOverride(let actor, let inner) = cue {
                subject = .actor(actor)
                cue = inner
            }
            switch cue {
            case .setDoor(let door, let open):
                state["door.\(door.rawValue)"] = "\(open)"
            case .setFlag(let flag):
                state["flag.\(flag)"] = "set"
            case .resumeDialogue(let node):
                state["dialogue.resume"] = node ?? "nil"
            case .suppressDialogue:
                state["dialogue.resume"] = "suppressed"
            case .letterbox(let visible):
                state["chrome.letterbox"] = "\(visible)"
            case .setCutsceneMode(let active):
                state["chrome.mode"] = "\(active)"
            case .moveViewPoint(let point, _):
                state["camera"] = "\(point)"
            case .moveViewObject(let actor, _):
                state["camera"] = "follow.\(actor.rawValue)"
            case .releaseCamera:
                state["camera"] = "released"
            case .cameraScale(let scale, _):
                state["camera.scale"] = "\(scale)"
            case .fadeToColor(let color, _):
                state["chrome.fade"] = "to.\(color)"
            case .fadeFromColor(let color, _):
                state["chrome.fade"] = "from.\(color)"
            case .jumpToPoint(let point, _), .moveToPoint(let point):
                state["actor.\(subject).position"] = "\(point)"
            case .followPath(let path, _):
                state["actor.\(subject).position"] = "\(path.last ?? .zero)"
            case .face(let facing):
                state["actor.\(subject).facing"] = "\(facing.rawValue)"
            case .faceObject(let target):
                state["actor.\(subject).facing"] = "toward.\(target.rawValue)"
            case .standUp:
                state["actor.\(subject).posture"] = "standing"
            case .wait, .displayStringHead, .playVoiceOver:
                continue
            case .actionOverride:
                preconditionFailure("Unwrapped above")
            }
        }
        return state
    }

    /// Exercises every execution class at once: parallel tracks, blocking
    /// locomotion, timed chrome, a camera scroll, and trailing state changes.
    private static let representativeCutscene = Cutscene(
        id: "test.representative",
        graceSeconds: 0,
        tracks: [
            CutsceneTrack(.world, [
                .setDoor(.officeEntrance, open: true),
                .setFlag("office.clientArrived")
            ]),
            CutsceneTrack(.camera, [
                .moveViewPoint(CGPoint(x: 100, y: 100), .fast),
                .moveViewObject(.client, .veryFast),
                .moveViewPoint(CGPoint(x: 400, y: 220), .standard)
            ]),
            CutsceneTrack(.actor(.detective), [
                .wait(.ticks(8)),
                .standUp
            ]),
            CutsceneTrack(.cameraZoom, [
                .cameraScale(0.9, .seconds(1))
            ]),
            // The master block, BG-shaped: chrome, a blocking join on someone
            // else's walk, then the beats that may only happen after it.
            CutsceneTrack(.chrome, [
                .setCutsceneMode(true),
                .letterbox(true),
                .suppressDialogue,
                .actionOverride(.client, .followPath([CGPoint(x: 0, y: 0), CGPoint(x: 380, y: 210)], .entering)),
                .actionOverride(.detective, .faceObject(.client)),
                .letterbox(false),
                .resumeDialogue(nodeID: "voss.monologue.5")
            ])
        ]
    )
}

/// `ActionOverride` — BG's join. Separate blocks give concurrency; the override
/// is how one block waits on another actor's work before continuing.
struct CutsceneActionOverrideTests {

    @Test func overrideBlocksTheIssuingTrackUntilTheActorFinishes() {
        var runner = CutsceneRunner()
        let walk = [CGPoint(x: 0, y: 0), CGPoint(x: 200, y: 0)]
        let step = runner.begin(
            Cutscene(id: "join", tracks: [
                CutsceneTrack(.chrome, [
                    .letterbox(true),
                    .actionOverride(.client, .followPath(walk, .entering)),
                    .letterbox(false)
                ])
            ]),
            at: 0
        )
        #expect(step.commands == [
            CutsceneCommand(.chrome, .letterbox(true)),
            CutsceneCommand(.chrome, .actionOverride(.client, .followPath(walk, .entering)))
        ])
        #expect(runner.advance(ticks: 500).commands.isEmpty, "Still waiting on her walk")

        // Completion is reported against the *issuing* track, not the overridden
        // actor — the override is that track's action, run elsewhere.
        let done = runner.noteCompleted(.chrome)
        #expect(done.commands == [CutsceneCommand(.chrome, .letterbox(false))])
        #expect(done.completion == .natural)
    }

    @Test func overrideOfATimedCueBlocksForThatCuesDuration() {
        var runner = CutsceneRunner()
        _ = runner.begin(
            Cutscene(id: "timed-join", tracks: [
                CutsceneTrack(.chrome, [
                    .actionOverride(.detective, .displayStringHead(stringKey: "k", .seconds(2))),
                    .letterbox(false)
                ])
            ]),
            at: 0
        )
        #expect(runner.advance(ticks: 29).commands.isEmpty)
        #expect(runner.advance(ticks: 1).commands == [CutsceneCommand(.chrome, .letterbox(false))])
    }

    @Test func overrideTerminalUnwrapsToTheInnerTerminal() {
        let cue = CutsceneCue.actionOverride(.client, .followPath([.zero, CGPoint(x: 9, y: 9)], .entering))
        #expect(cue.terminal == .actionOverride(.client, .jumpToPoint(CGPoint(x: 9, y: 9), .entering)))
        #expect(cue.isOpenEnded)
        #expect(!CutsceneCue.actionOverride(.client, .face(.south)).isOpenEnded)
    }
}
