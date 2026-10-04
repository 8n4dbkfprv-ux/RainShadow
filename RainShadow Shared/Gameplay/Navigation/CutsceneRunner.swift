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

/// GemRB EvaluateAllBlocks / HandleActionOverride / Scriptable::ProcessActions:
/// actor queues append in script order; overrides release the issuer immediately.
struct CutsceneRunner: Equatable, Sendable {
    private struct Entry: Equatable, Sendable {
        let cue: CutsceneCue
        let overridden: Bool
    }
    private enum Wait: Equatable, Sendable { case ready, reporting, until(Int) }
    private struct Queue: Equatable, Sendable {
        let subject: CutsceneSubject
        var pending: [Entry] = []
        var active: Entry?
        var wait: Wait = .ready
        var isEmpty: Bool { pending.isEmpty && active == nil }
    }
    private(set) var gate = BreakableCutsceneGate()
    private(set) var cutscene: Cutscene?
    private var queues: [Queue] = []
    private var tick = 0
    var isPlaying: Bool { gate.isActive }
    var wasBroken: Bool { gate.wasBroken }
    var elapsedTicks: Int { tick }

    mutating func begin(_ cutscene: Cutscene, at now: TimeInterval) -> CutsceneStep {
        reset()
        self.cutscene = cutscene
        for track in cutscene.tracks {
            let index = queueIndex(for: track.subject)
            queues[index].pending += track.cues.map { Entry(cue: $0, overridden: false) }
        }
        gate.begin(at: now, graceSeconds: cutscene.graceSeconds, breakable: cutscene.isBreakable)
        return pump()
    }

    mutating func advance(ticks: Int) -> CutsceneStep {
        guard isPlaying, ticks > 0 else { return .none }
        var commands: [CutsceneCommand] = []
        var completion: CutsceneCompletionReason?
        for _ in 0..<ticks where isPlaying {
            tick += 1
            for index in queues.indices {
                if case .until(let deadline) = queues[index].wait, tick >= deadline {
                    queues[index].active = nil
                    queues[index].wait = .ready
                }
            }
            let step = pump()
            commands += step.commands
            completion = step.completion
        }
        return CutsceneStep(commands: commands, completion: completion)
    }

    mutating func noteCompleted(_ subject: CutsceneSubject) -> CutsceneStep {
        guard isPlaying, let index = queues.firstIndex(where: { $0.subject == subject }),
              queues[index].wait == .reporting else { return .none }
        queues[index].active = nil
        queues[index].wait = .ready
        return pump()
    }

    func canSkip(at now: TimeInterval) -> Bool { gate.canSkip(at: now) }

    mutating func skip(at now: TimeInterval) -> CutsceneStep {
        guard let cutscene, canSkip(at: now) else { return .none }
        var commands: [CutsceneCommand] = []
        if let recovery = cutscene.skipTracks {
            for track in recovery {
                commands += track.cues.map { terminalCommand(track.subject, $0) }
            }
        } else {
            for queue in queues {
                for entry in (queue.active.map { [$0] } ?? []) + queue.pending {
                    commands.append(terminalCommand(queue.subject, entry.cue))
                }
            }
        }
        queues = []
        guard gate.markCompleted(reason: .skipped) else { return .none }
        return CutsceneStep(commands: commands, completion: .skipped)
    }

    mutating func reset() {
        gate.reset()
        cutscene = nil
        queues = []
        tick = 0
    }

    private func terminalCommand(_ subject: CutsceneSubject, _ cue: CutsceneCue) -> CutsceneCommand {
        if case .actionOverride(let actor, let inner) = cue { return terminalCommand(.actor(actor), inner) }
        return CutsceneCommand(subject, cue.terminal)
    }

    private mutating func queueIndex(for subject: CutsceneSubject) -> Int {
        if let index = queues.firstIndex(where: { $0.subject == subject }) { return index }
        queues.append(Queue(subject: subject))
        return queues.count - 1
    }

    private mutating func pump() -> CutsceneStep {
        guard isPlaying else { return .none }
        var commands: [CutsceneCommand] = []
        var progressed = true
        while progressed {
            progressed = false
            var index = 0
            while index < queues.count {
                guard queues[index].wait == .ready, !queues[index].pending.isEmpty else {
                    index += 1
                    continue
                }
                let entry = queues[index].pending.removeFirst()
                let subject = queues[index].subject
                progressed = true
                if case .actionOverride(let actor, let cue) = entry.cue {
                    let target = queueIndex(for: .actor(actor))
                    queues[target].pending.removeAll { !$0.overridden }
                    if queues[target].active?.overridden != true {
                        queues[target].active = nil
                        queues[target].wait = .ready
                        commands.append(CutsceneCommand(.actor(actor), .clearActions))
                    }
                    queues[target].pending.append(Entry(cue: cue, overridden: true))
                    continue
                }
                commands.append(CutsceneCommand(subject, entry.cue))
                if entry.cue.isOpenEnded {
                    queues[index].active = entry
                    queues[index].wait = .reporting
                } else if entry.cue.duration.ticks > 0 {
                    queues[index].active = entry
                    queues[index].wait = .until(tick + entry.cue.duration.ticks)
                }
            }
        }
        let completion: CutsceneCompletionReason? = queues.allSatisfy(\.isEmpty) && gate.markCompleted(reason: .natural) ? .natural : nil
        return CutsceneStep(commands: commands, completion: completion)
    }
}
