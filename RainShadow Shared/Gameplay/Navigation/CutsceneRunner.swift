import CoreGraphics
import Foundation

/// One cue addressed to one subject — what the director is being told to do.
struct CutsceneCommand: Equatable, Sendable {
    let subject: CutsceneSubject
    let cue: CutsceneCue

    init(_ subject: CutsceneSubject, _ cue: CutsceneCue) {
        self.subject = subject
        self.cue = cue
    }
}

/// The result of advancing the runner: cues to start now, plus the completion
/// reason on the one step that ends the cutscene.
///
/// Carrying the reason *in the step* is what removes the shipped
/// `cutsceneBreakRequested` / `effectiveReason(_:)` latch. Locomotion could never
/// know why it stopped, so the scene had to set a flag, snap the actor, and read
/// the flag back out on the way through the terminal path
/// (`CinematicSystemRoadmap` §6, "Known seam"). The runner knows, because the
/// runner is the thing that was asked.
struct CutsceneStep: Equatable, Sendable {
    let commands: [CutsceneCommand]
    /// Non-nil exactly once per run, on the step that completed it.
    let completion: CutsceneCompletionReason?

    static let none = CutsceneStep(commands: [], completion: nil)

    var isEmpty: Bool { commands.isEmpty && completion == nil }
}

/// Plays a `Cutscene`: parallel tracks, sequential cues, single-fire completion.
///
/// Pure — no SpriteKit, no wall clock, no world access. It is advanced in whole
/// logic ticks and told when open-ended cues finish, which makes an entire
/// cutscene's timing testable without a render loop. Same split as
/// `DialogueSession` (pure graph walk) and `DialoguePresenter` (the SpriteKit half).
struct CutsceneRunner: Equatable, Sendable {

    /// What a track is waiting on before it may start its next cue.
    private enum TrackWait: Equatable, Sendable {
        /// Free to start the next cue on this pump.
        case ready
        /// Timed cue in flight; ready once `tick` reaches this deadline.
        case until(Int)
        /// Open-ended cue in flight; ready when the director reports completion.
        case reporting
        /// Cues exhausted.
        case done
    }

    private(set) var gate = BreakableCutsceneGate()
    private(set) var cutscene: Cutscene?

    /// Next cue index per track.
    private var cursors: [Int] = []
    /// Index of the cue currently occupying each track, if any. A skip must
    /// re-apply it in terminal form — a half-walked path still owes its endpoint.
    private var inFlight: [Int?] = []
    private var waits: [TrackWait] = []
    private var tick = 0

    init() {}

    // MARK: - Lifecycle

    /// Arms `cutscene` and returns everything that starts on tick zero.
    ///
    /// BG's `ClearAllActions()` before `StartCutSceneMode()` is the director's
    /// job — the runner has no world to clear.
    mutating func begin(_ cutscene: Cutscene, at now: TimeInterval) -> CutsceneStep {
        assert(
            Set(cutscene.tracks.map(\.subject)).count == cutscene.tracks.count,
            "Cutscene \"\(cutscene.id)\" has two tracks for one subject. In BG that "
                + "serialises them onto a single action list; here it is an authoring error — "
                + "merge the cues into one track so their order is explicit."
        )
        self.cutscene = cutscene
        cursors = Array(repeating: 0, count: cutscene.tracks.count)
        inFlight = Array(repeating: nil, count: cutscene.tracks.count)
        waits = Array(repeating: .ready, count: cutscene.tracks.count)
        tick = 0
        gate.begin(at: now, graceSeconds: cutscene.graceSeconds, breakable: cutscene.isBreakable)
        return pump()
    }

    /// Advances the clock by whole logic ticks and starts whatever came due.
    mutating func advance(ticks: Int) -> CutsceneStep {
        guard gate.isActive, ticks > 0 else { return .none }
        tick += ticks
        for index in waits.indices where isDue(waits[index]) {
            waits[index] = .ready
            inFlight[index] = nil
        }
        return pump()
    }

    /// Reports that an open-ended cue (locomotion, a camera scroll, standing up)
    /// finished. BG's `MoveToPoint` blocks the same way.
    mutating func noteCompleted(_ subject: CutsceneSubject) -> CutsceneStep {
        guard gate.isActive, let index = trackIndex(for: subject), waits[index] == .reporting else {
            return .none
        }
        waits[index] = .ready
        inFlight[index] = nil
        return pump()
    }

    /// BG:EE `SetCutSceneBreakable` + ESC: is a skip allowed right now?
    func canSkip(at now: TimeInterval) -> Bool {
        gate.canSkip(at: now)
    }

    /// Breaks the cutscene, emitting every cue that has not finished — the
    /// in-flight one included — in zero-duration terminal form.
    ///
    /// This is the whole safety argument. The skip path is not a second
    /// implementation of the ending that has to be kept in sync with the first;
    /// it is the *same cue list*, played at zero duration. A cue added to a
    /// cutscene is covered by skip the moment it is authored.
    mutating func skip(at now: TimeInterval) -> CutsceneStep {
        guard let cutscene, gate.canSkip(at: now) else { return .none }
        var commands: [CutsceneCommand] = []
        for (index, track) in cutscene.tracks.enumerated() {
            if let flying = inFlight[index] {
                commands.append(CutsceneCommand(track.subject, track.cues[flying].terminal))
            }
            for cue in track.cues[cursors[index]...] {
                commands.append(CutsceneCommand(track.subject, cue.terminal))
            }
            cursors[index] = track.cues.count
            inFlight[index] = nil
            waits[index] = .done
        }
        guard gate.markCompleted(reason: .skipped) else { return .none }
        return CutsceneStep(commands: commands, completion: .skipped)
    }

    /// Drops all state. A scene torn down mid-cutscene must not leave a gate armed.
    mutating func reset() {
        gate.reset()
        cutscene = nil
        cursors = []
        inFlight = []
        waits = []
        tick = 0
    }

    // MARK: - Introspection

    var isPlaying: Bool { gate.isActive }
    /// BG:EE `CutSceneBroken()`.
    var wasBroken: Bool { gate.wasBroken }
    var elapsedTicks: Int { tick }

    // MARK: - Internals

    private func isDue(_ wait: TrackWait) -> Bool {
        if case .until(let deadline) = wait { return tick >= deadline }
        return false
    }

    private func trackIndex(for subject: CutsceneSubject) -> Int? {
        cutscene?.tracks.firstIndex { $0.subject == subject }
    }

    /// Starts every cue that can start now, repeating so a run of instant cues
    /// lands in one step. BG queues them into the same AI update; so do we.
    private mutating func pump() -> CutsceneStep {
        guard let cutscene, gate.isActive else { return .none }
        var commands: [CutsceneCommand] = []

        var progressed = true
        while progressed {
            progressed = false
            for (index, track) in cutscene.tracks.enumerated() where waits[index] == .ready {
                guard cursors[index] < track.cues.count else {
                    waits[index] = .done
                    continue
                }
                let cueIndex = cursors[index]
                let cue = track.cues[cueIndex]
                cursors[index] += 1
                commands.append(CutsceneCommand(track.subject, cue))
                progressed = true

                if cue.isOpenEnded {
                    inFlight[index] = cueIndex
                    waits[index] = .reporting
                } else {
                    let ticks = cue.duration.ticks
                    if ticks > 0 {
                        inFlight[index] = cueIndex
                        waits[index] = .until(tick + ticks)
                    } else {
                        inFlight[index] = nil
                        waits[index] = .ready
                    }
                }
            }
        }

        let finished = waits.allSatisfy { $0 == .done }
        guard finished, gate.markCompleted(reason: .natural) else {
            return CutsceneStep(commands: commands, completion: nil)
        }
        return CutsceneStep(commands: commands, completion: .natural)
    }
}
