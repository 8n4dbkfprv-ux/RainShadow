import CoreGraphics
import Foundation

struct CutsceneCommand: Equatable, Sendable {
    let subject: CutsceneSubject
    let cue: CutsceneCue

    init(_ subject: CutsceneSubject, _ cue: CutsceneCue) {
        self.subject = subject
        self.cue = cue
    }
}

struct CutsceneStep: Equatable, Sendable {
    let commands: [CutsceneCommand]
    let completion: CutsceneCompletionReason?
    static let none = CutsceneStep(commands: [], completion: nil)
    var isEmpty: Bool { commands.isEmpty && completion == nil }
}

/// Action queues modelled on GemRB 1c45c185 GameScript::EvaluateAllBlocks,
/// ExecuteAction/HandleActionOverride and Scriptable::ProcessActions.
/// See CinematicParityAuditOct02.md for the quoted upstream comparisons.
struct CutsceneRunner: Equatable, Sendable {
    private struct Entry: Equatable, Sendable {
        let cue: CutsceneCue
        let overridden: Bool
    }
    private enum Wait: Equatable, Sendable {
        case ready, reporting, until(Int), animation(until: Int)
    }
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
    private var actionTick = 0
    private(set) var fade = CutsceneFadeTimer()

    var isPlaying: Bool { gate.isActive }
    var wasBroken: Bool { gate.wasBroken }
    var elapsedTicks: Int { tick }
    var isFading: Bool { fade.isFading }

    mutating func begin(_ cutscene: Cutscene, at now: TimeInterval) -> CutsceneStep {
        reset()
        self.cutscene = cutscene
        // Repeated CutSceneId blocks append to the same actor queue in script order.
        for track in cutscene.tracks {
            let index = queueIndex(for: track.subject)
            queues[index].pending += track.cues.map { Entry(cue: $0, overridden: false) }
        }
        gate.begin(at: now, breakable: cutscene.isBreakable)
        return pump()
    }

    mutating func advance(ticks: Int) -> CutsceneStep {
        guard ticks > 0 else { return .none }
        var commands: [CutsceneCommand] = []
        var completion: CutsceneCompletionReason?
        // Never discard intermediate deadlines during a multi-tick render frame.
        for _ in 0..<ticks {
            fade.advance()
            guard isPlaying else { continue }
            tick += 1
            if isFading { continue }
            // GlobalTimer tests IsFading after DoFadeStep; scripts resume on
            // the update that completes the fade, not one update later.
            actionTick += 1
            for index in queues.indices {
                switch queues[index].wait {
                case .until(let deadline), .animation(let deadline):
                    if actionTick >= deadline {
                        queues[index].active = nil
                        queues[index].wait = .ready
                    }
                default: break
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

    mutating func noteAnimationCompleted(_ subject: CutsceneSubject, sequence: CutsceneSequence) -> CutsceneStep {
        guard isPlaying, let index = queues.firstIndex(where: { $0.subject == subject }),
              queues[index].active?.cue == .waitAnimation(sequence) else { return .none }
        queues[index].active = nil
        queues[index].wait = .ready
        return pump()
    }

    func canSkip(at now: TimeInterval) -> Bool { gate.canSkip(at: now) }

    mutating func skip(at now: TimeInterval) -> CutsceneStep {
        guard let cutscene, gate.canSkip(at: now) else { return .none }
        gate.markBroken()
        // Escape interrupts the current actions; it does not execute their tails.
        // The area script's CutSceneBroken failsafe is a new set of normal queues.
        var commands = [CutsceneCommand(.world, .setCutsceneMode(false))]
        for queue in queues {
            if case .actor = queue.subject {
                commands.append(CutsceneCommand(queue.subject, .clearActions))
            }
        }
        queues = []
        for track in cutscene.skipTracks ?? [] {
            let index = queueIndex(for: track.subject)
            queues[index].pending += track.cues.map { Entry(cue: $0, overridden: false) }
        }
        let recovery = pump()
        commands += recovery.commands
        return CutsceneStep(commands: commands, completion: recovery.completion)
    }

    mutating func reset() {
        gate.reset()
        cutscene = nil
        queues = []
        tick = 0
        actionTick = 0
        fade.clear()
    }

    private mutating func queueIndex(for subject: CutsceneSubject) -> Int {
        if let index = queues.firstIndex(where: { $0.subject == subject }) { return index }
        queues.append(Queue(subject: subject))
        return queues.count - 1
    }

    private mutating func pump() -> CutsceneStep {
        guard isPlaying, !isFading else { return .none }
        var commands: [CutsceneCommand] = []
        var progressed = true
        while progressed && !isFading {
            progressed = false
            // Index loop admits actors introduced by ActionOverride in this pump.
            var index = 0
            while index < queues.count && !isFading {
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
                if case .setCutsceneBreakable(let enabled) = entry.cue {
                    gate.isBreakable = enabled
                }
                if case .fadeToColor(_, let duration) = entry.cue {
                    fade.fadeTo(ticks: duration.ticks)
                } else if case .fadeFromColor(_, let duration) = entry.cue {
                    fade.fadeFrom(ticks: duration.ticks)
                } else if case .waitAnimation = entry.cue {
                    queues[index].active = entry
                    // WaitAnimation releases once int1Parameter > round_size (90).
                    queues[index].wait = .animation(until: actionTick + 91)
                } else if entry.cue.isOpenEnded {
                    queues[index].active = entry
                    queues[index].wait = .reporting
                } else if entry.cue.duration.ticks > 0 {
                    queues[index].active = entry
                    queues[index].wait = .until(actionTick + entry.cue.duration.ticks)
                }
            }
        }
        let finished = !isFading && queues.allSatisfy(\.isEmpty)
        let reason: CutsceneCompletionReason = gate.wasBroken ? .skipped : .natural
        let completion: CutsceneCompletionReason? = finished && gate.markCompleted(reason: reason) ? reason : nil
        return CutsceneStep(commands: commands, completion: completion)
    }
}

/// GemRB 1c45c185 GlobalTimer::{SetFadeToColor, SetFadeFromColor, DoFadeStep}.
/// BG2 gametime.2da: FADE_DEFAULT 20, FADE_RESET 150. All calls advance one tick,
/// avoiding the upstream multi-tick FadeFrom overshoot. Alpha truncates to a byte.
struct CutsceneFadeTimer: Equatable, Sendable {
    private(set) var alpha = 0
    private(set) var lastDuration = 20
    private var toCounter = 0
    private var toMaximum = 0
    private var fromCounter = 0
    private var fromMaximum = 0
    private var fallback = 0

    var isFading: Bool { toCounter != 0 || fromCounter != fromMaximum }

    mutating func fadeTo(ticks: Int) {
        if ticks > 0 { lastDuration = ticks }
        toCounter = lastDuration
        toMaximum = toCounter
        fallback = 150
        fromCounter = 0
        fromMaximum = 0
    }

    mutating func fadeFrom(ticks: Int) {
        if ticks > 0 { lastDuration = ticks }
        fallback = 0
        fromCounter = 0
        fromMaximum = lastDuration
    }

    mutating func advance() {
        if fallback > 0 {
            fallback -= 1
            if fallback == 0 { alpha = 0; return }
        }
        if toCounter > 0 {
            if fallback > 0 { fallback += 1 }
            toCounter -= 1
            alpha = Int(255 * (Double(toMaximum - toCounter) / Double(toMaximum)))
        } else if fromCounter != fromMaximum {
            fromCounter += fromCounter > fromMaximum ? -1 : 1
            alpha = Int(255 * (Double(fromMaximum - fromCounter) / Double(fromMaximum)))
        }
    }

    /// A scene teardown clears its overlay, but zero-duration fades still reuse
    /// the last duration when a new sequence starts in the same scene.
    mutating func clear() {
        let duration = lastDuration
        self = Self()
        lastDuration = duration
    }
}
