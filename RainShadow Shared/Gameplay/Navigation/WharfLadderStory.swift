import Foundation
import CoreGraphics

/// Story combat's persistent contract. Dialogue requests an encounter; this resolver
/// consumes it once. Cinematics are presentation and cannot grant rewards themselves.
enum WharfLadderStory {
    enum Encounter: String, CaseIterable, Sendable {
        case gate, lane, clockroom, e1
        var prefix: String { self == .e1 ? "combat.e1" : "combat.a1.\(rawValue)" }
        var graph: DialogueGraph { WharfLadderDialogue.graph(self == .e1 ? "wharf-ladder" : "wharf-ladder.\(rawValue)") }
        var crewCount: Int { self == .clockroom ? 3 : 2 }
    }
    enum Outcome { case won, lost, crossed }
    static let exterior = AreaID("city_wharf_ladder")
    static let interior = AreaID("interior_shipping_office")
    static let activeVisit = "wharf-ladder.runtime.visit-active"
    static let visit = "wharf-ladder.runtime.visit"
    static let aftermath = "wharf-ladder.runtime.aftermath."
    static let retainer = "empty-coat.case.retainer-credited"
    static let payment = "wharf-ladder.case.merrick-payment-settled"
    static let silverPence = 12
    static let paymentPence = 50 * silverPence

    static func beginVisit(_ state: inout CaseState) {
        guard !state.hasFlag(activeVisit) else { return }
        state.setFlag(activeVisit)
        state.addToCounter(visit, 1)
    }
    static func endVisit(_ state: inout CaseState) { state.clearFlag(activeVisit) }
    static func crossed(_ encounter: Encounter, in state: CaseState) -> Bool {
        state.counter(visit) > 0 && state.counter(encounter.prefix + ".visit") == state.counter(visit)
    }
    static func nextFloor(in state: CaseState) -> Encounter? {
        [.gate, .lane, .clockroom].first { !crossed($0, in: state) }
    }
    static func pendingAftermath(in state: CaseState) -> Encounter? {
        Encounter.allCases.first { state.hasFlag(aftermath + $0.rawValue) }
    }
    static func requested(_ encounter: Encounter, in state: CaseState) -> Bool {
        requestFlags(encounter).contains(where: state.hasFlag)
    }
    static func quiet(_ encounter: Encounter, in state: CaseState) -> Bool {
        switch encounter {
        case .gate: state.hasFlag("combat.a1.gate.walkedPast")
        case .lane: state.hasFlag("combat.a1.lane.slip")
        case .clockroom: state.hasFlag("combat.a1.clockroom.letPass")
        case .e1: false
        }
    }
    private static func requestFlags(_ encounter: Encounter) -> [String] {
        switch encounter {
        case .gate: [encounter.prefix + ".trigger", encounter.prefix + ".walkedPast"]
        case .lane: [encounter.prefix + ".trigger", encounter.prefix + ".slip"]
        case .clockroom: [encounter.prefix + ".trigger", encounter.prefix + ".letPass"]
        case .e1: ["combat.e1.trigger.desk", "combat.e1.trigger.sealroom"]
        }
    }
    static func clearRequests(_ encounter: Encounter, in state: inout CaseState) {
        for flag in requestFlags(encounter) + [encounter.prefix + ".opening.firstBlow", encounter.prefix + ".opening.rattled"] {
            state.clearFlag(flag)
        }
    }
    /// Escape does not grant crossing, loot, injuries, or loss narration.
    static func flee(_ encounter: Encounter, in state: inout CaseState) {
        clearRequests(encounter, in: &state)
        state.clearFlag(aftermath + encounter.rawValue)
        state.setFlag(encounter.prefix + ".outcome.fled")
    }
    /// Auto-resolve is always nonlethal victory; the explicit loss supports future
    /// played combat without changing the dialogue or progression contract.
    @discardableResult
    static func resolve(_ encounter: Encounter, outcome: Outcome? = nil, in state: inout CaseState) -> Bool {
        guard requested(encounter, in: state) else { return false }
        guard !crossed(encounter, in: state), !(encounter == .e1 && state.hasFlag("combat.e1.done")) else {
            clearRequests(encounter, in: &state)
            return false
        }
        let result = outcome ?? (quiet(encounter, in: state) ? .crossed : .won)
        let firstFight = !state.hasFlag(encounter.prefix + ".fought")
        let opening = state.hasFlag(encounter.prefix + ".opening.firstBlow") ? "firstBlow"
            : state.hasFlag(encounter.prefix + ".opening.rattled") ? "rattled" : "standard"
        clearRequests(encounter, in: &state)
        state.setFlag(encounter.prefix + ".done")
        state.setCounter(encounter.prefix + ".visit", to: state.counter(visit))
        state.setFlag(aftermath + encounter.rawValue)
        if result != .crossed {
            state.setFlag(encounter.prefix + ".fought")
            for old in ["firstBlow", "rattled", "standard"] { state.clearFlag(encounter.prefix + ".last-opening." + old) }
            state.setFlag(encounter.prefix + ".last-opening.\(opening)")
        }
        let outcomeID = result == .won ? "won" : result == .lost ? "lost" : "slipped"
        for old in ["won", "lost", "slipped", "avoided", "fled"] { state.clearFlag(encounter.prefix + ".outcome." + old) }
        state.setFlag(encounter.prefix + ".outcome." + outcomeID)
        if outcome == nil && result == .won { state.setFlag(encounter.prefix + ".auto-resolved") }
        if encounter == .lane && firstFight && result != .crossed {
            state.grantEvidence("evidence.a1.lane.chit")
            journal("a1.chit", "The lane crew carried a chalk chit with a crate mark. The mark belongs to the case now.", in: &state)
        }
        if encounter == .clockroom {
            if result == .won { state.grantEvidence("evidence.a1.clockroom.chalk") }
            if result != .crossed {
                state.setFlag("injury.voss.bruised")
                journal("a1.clockroom", result == .won
                    ? "Hobb's crew are alive. I took the night's chalk and bruised ribs. The chalk may open a yard door; it does not tell me when Hobb leaves his clock."
                    : "I woke bruised outside the clock room. No chalk, but the way to Merrick was open.", in: &state)
            }
        }
        if encounter == .e1 {
            state.addToCounter("watch.attention", 1)
            state.setFlag("injury.voss.bruised")
            if result == .won {
                state.setFlag("combat.e1.bram.knockedDown")
                state.grantEvidence("evidence.payTally.crateMark")
            } else {
                state.evidenceIDs.remove("evidence.sealMark.scrap")
            }
            journal("e1", result == .won
                ? "Ketch and Bram are alive. Bram's pay tally carries the crate mark. The noise brought the night-men; Merrick has shut his mouth. I came away bruised."
                : "The folio fight left me bruised on the quay. The seal scrap is gone. The Watch heard the noise.", in: &state)
        }
        return true
    }
    static func acknowledge(_ encounter: Encounter, in state: inout CaseState) {
        state.clearFlag(aftermath + encounter.rawValue)
    }
    static func creditRetainer(in state: inout CaseState, wallet: inout Int) {
        guard !state.hasFlag(retainer) else { return }
        wallet += 200 * silverPence
        state.setFlag(retainer)
    }
    static func settlePayment(in state: inout CaseState, wallet: inout Int) {
        guard state.hasFlag("wharf-ladder.case.merrick-paid50"), !state.hasFlag(payment) else { return }
        precondition(wallet >= paymentPence, "The paid reply must be affordability-gated")
        wallet -= paymentPence
        state.setFlag(payment)
    }
    private static func journal(_ id: String, _ text: String, in state: inout CaseState) {
        state.queueJournal(.init(id: "wharf-ladder.story." + id, kind: .chronology, text: text))
    }
    /// No invented strikes: face the crew, cut away, clear them under black,
    /// then return to the readable aftermath. Skip uses the same terminal cue.
    static func cinematic(for encounter: Encounter) -> Cutscene {
        Cutscene(id: "wharf-ladder.resolve." + encounter.rawValue, tracks: [
            CutsceneTrack(.chrome, [
                .setCutsceneMode(true), .letterbox(true),
                .wait(.seconds(0.7)), .fadeToColor(.black, .seconds(0.35)),
                .setFlag("wharf-ladder.clear-crew"), .wait(.seconds(0.5)),
                .fadeFromColor(.black, .seconds(0.35)), .letterbox(false), .setCutsceneMode(false)
            ])
        ])
    }
}

enum WharfLadderDialogue {
    static let names = ["wharf-ladder", "wharf-ladder.gate", "wharf-ladder.lane", "wharf-ladder.clockroom", "wharf-ladder.story"]
    static func graph(_ name: String) -> DialogueGraph {
        do { return try DialogueGraphLoader.loadCached(id: "case." + name, resourceName: name + ".dialogue") }
        catch { preconditionFailure("Wharf Ladder dialogue \(name): \(error)") }
    }
    static var graphs: [DialogueGraph] { names.map(graph) }
    static func narration(_ id: String) -> DialogueGraph {
        let source = graph("wharf-ladder.story")
        return DialogueGraph(id: source.id, startNodeID: id, nodes: source.nodes)
    }
}
