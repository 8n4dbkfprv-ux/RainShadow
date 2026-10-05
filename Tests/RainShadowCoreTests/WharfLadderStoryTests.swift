import Foundation
import CoreGraphics
import Testing
@testable import RainShadowCore
@testable import RainShadowPersistence

struct WharfLadderStoryTests {
    private func initial() -> CaseState {
        var state = CaseState(caseID: EmptyCoatJournalContent.caseID)
        WharfLadderStory.beginVisit(&state)
        state.setCounter("wallet.pence", to: 2400)
        return state
    }
    private func session(_ graph: DialogueGraph, _ state: CaseState) -> DialogueSession {
        DialogueSession(graph: graph, context: .init(caseState: state, dialogueState: .init(graphID: graph.id)))
    }
    private func fight(_ encounter: WharfLadderStory.Encounter, choice: Int, state: inout CaseState) throws {
        var talk = session(encounter.graph, state)
        for _ in 0..<6 {
            if !talk.visibleChoices.isEmpty { break }
            _ = talk.advanceContinue()
        }
        #expect(talk.visibleChoices.count == 3)
        _ = talk.selectChoice(at: choice)
        #expect(talk.currentNode?.endsDialogue == true)
        state = talk.context.caseState
        #expect(WharfLadderStory.requested(encounter, in: state))
        #expect(WharfLadderStory.resolve(encounter, in: &state))
    }
    @Test func contentLoadsAndEveryNarrationHasAValidEnding() throws {
        for graph in WharfLadderDialogue.graphs {
            try graph.validateAuthoring()
            #expect(graph.integrityReport().isSound)
            for node in graph.nodes { #expect(!node.text.hasPrefix("dlg.")) }
        }
        for e in [WharfLadderStory.Encounter.gate, .lane, .clockroom] {
            for result in ["won", "lost", "crossed"] {
                let graph = WharfLadderDialogue.narration(e.rawValue + "." + result)
                try graph.validateAuthoring()
                #expect(session(graph, initial()).currentNode?.endsDialogue == true)
            }
        }
    }
    @Test(arguments: [0, 1, 2]) func allFirstVisitRepliesFightAndAdvanceInOrder(_ choice: Int) throws {
        var state = initial()
        // Even prematurely supplied knowledge cannot bypass the first visit.
        state.grantKnowledge("knowledge.nightClock.interval")
        state.grantKnowledge("knowledge.wharfLadder.tideGap")
        state.setFlag("wharf-ladder.case.merrick-paid50")
        for encounter in [WharfLadderStory.Encounter.gate, .lane, .clockroom] {
            #expect(WharfLadderStory.nextFloor(in: state) == encounter)
            try fight(encounter, choice: choice, state: &state)
            #expect(WharfLadderStory.pendingAftermath(in: state) == encounter)
            #expect(!WharfLadderStory.requested(encounter, in: state))
            #expect(!state.hasFlag(encounter.prefix + ".opening.firstBlow"))
            #expect(!state.hasFlag(encounter.prefix + ".opening.rattled"))
            WharfLadderStory.acknowledge(encounter, in: &state)
        }
        #expect(WharfLadderStory.nextFloor(in: state) == nil)
        #expect(state.hasEvidence("evidence.a1.lane.chit"))
        #expect(state.hasEvidence("evidence.a1.clockroom.chalk"))
        #expect(state.hasFlag("injury.voss.bruised"))
        #expect(state.counter("watch.attention") == 0)
    }
    @Test func clockVictoryDoesNotInventTheSideCaseIntervalAndLossStillProgresses() throws {
        for outcome in [WharfLadderStory.Outcome.won, .lost] {
            var state = initial()
            state.setFlag("combat.a1.clockroom.trigger")
            WharfLadderStory.resolve(.clockroom, outcome: outcome, in: &state)
            #expect(state.hasFlag("combat.a1.clockroom.done"))
            #expect(state.hasEvidence("evidence.a1.clockroom.chalk") == (outcome == .won))
            #expect(!state.hasKnowledge("knowledge.nightClock.interval"))
        }
    }
    @Test func returnVisitUsesEarnedQuietEntries() throws {
        var state = initial()
        state.setFlag("wharf-ladder.case.visited")
        state.setFlag("wharf-ladder.case.merrick-paid50")
        state.grantKnowledge("knowledge.wharfLadder.tideGap")
        state.grantKnowledge("knowledge.nightClock.interval")
        WharfLadderStory.endVisit(&state)
        WharfLadderStory.beginVisit(&state)
        for (encounter, entry) in [(WharfLadderStory.Encounter.gate, "gate.merrick"), (.lane, "lane.slip"), (.clockroom, "clock.interval")] {
            var talk = session(encounter.graph, state)
            #expect(talk.currentNodeID == entry)
            _ = talk.selectChoice(at: 0)
            state = talk.context.caseState
            #expect(WharfLadderStory.quiet(encounter, in: state))
            WharfLadderStory.resolve(encounter, in: &state)
            WharfLadderStory.acknowledge(encounter, in: &state)
        }
        #expect(state.evidenceIDs.isEmpty)
        #expect(!state.hasFlag("injury.voss.bruised"))
        #expect(WharfLadderStory.nextFloor(in: state) == nil)
    }
    @Test func repeatsCannotFarmChitsOrKeepAnOldOpening() throws {
        var state = initial()
        try fight(.lane, choice: 2, state: &state)
        WharfLadderStory.acknowledge(.lane, in: &state)
        state.evidenceIDs.remove("evidence.a1.lane.chit")
        state.setFlag("combat.a1.lane.trigger")
        #expect(!WharfLadderStory.resolve(.lane, in: &state))
        WharfLadderStory.endVisit(&state)
        WharfLadderStory.beginVisit(&state)
        try fight(.lane, choice: 0, state: &state)
        #expect(!state.hasEvidence("evidence.a1.lane.chit"))
        #expect(state.hasFlag("combat.a1.lane.last-opening.standard"))
        #expect(!state.hasFlag("combat.a1.lane.last-opening.firstBlow"))
    }
    @Test func retainerAndPaymentAreExactlyOnceAndPaidReplyIsAffordable() throws {
        var state = initial()
        var wallet = 0
        WharfLadderStory.creditRetainer(in: &state, wallet: &wallet)
        WharfLadderStory.creditRetainer(in: &state, wallet: &wallet)
        #expect(wallet == 2400)
        state.setFlag("wharf-ladder.case.merrick-paid50")
        WharfLadderStory.settlePayment(in: &state, wallet: &wallet)
        WharfLadderStory.settlePayment(in: &state, wallet: &wallet)
        #expect(wallet == 1800)
        for (balance, count) in [(599, 2), (600, 3)] {
            state.setCounter("wallet.pence", to: balance)
            var talk = session(WharfLadderDialogue.graph("wharf-ladder"), state)
            _ = talk.jump(to: "merrick.price")
            #expect(talk.visibleChoices.count == count)
        }
    }
    @Test func e1WinLossAndAftermathAreIdempotent() throws {
        for outcome in [WharfLadderStory.Outcome.won, .lost] {
            var state = initial()
            state.grantEvidence("evidence.sealMark.scrap")
            state.setFlag("combat.e1.trigger.desk")
            #expect(WharfLadderStory.resolve(.e1, outcome: outcome, in: &state))
            #expect(state.counter("watch.attention") == 1)
            #expect(state.hasEvidence("evidence.payTally.crateMark") == (outcome == .won))
            #expect(state.hasEvidence("evidence.sealMark.scrap") == (outcome == .won))
            #expect(session(WharfLadderDialogue.graph("wharf-ladder"), state).currentNodeID == (outcome == .won ? "aftermath.won" : "aftermath.lost"))
            state.setFlag("combat.e1.trigger.sealroom")
            #expect(!WharfLadderStory.resolve(.e1, in: &state))
            #expect(state.counter("watch.attention") == 1)
            #expect(!WharfLadderStory.requested(.e1, in: state))
        }
    }
    @Test(arguments: ["warm", "dry-true", "dry-bluff", "sharp"])
    func officeApproachesReachAvoidanceOrAResolvableE1(_ route: String) throws {
        var state = initial()
        state.setFlag("combat.a1.clockroom.done")
        var talk = session(WharfLadderDialogue.graph("wharf-ladder"), state)
        var finished = false
        for _ in 0..<100 {
            let node = try #require(talk.currentNode)
            if node.endsDialogue { finished = true; break }
            let choices = talk.visibleChoices
            if choices.isEmpty { _ = talk.advanceContinue(); continue }
            let desired: String?
            switch node.id {
            case "merrick.greet": desired = route == "dry-true" ? "runner.hello" : "merrick.price"
            case "runner.hello": desired = "runner.told"
            case "merrick.price": desired = route == "warm" ? "voss.paid" : route == "sharp" ? "merrick.threat" : "merrick.favour"
            case "merrick.whisper": desired = talk.context.caseState.hasKnowledge("knowledge.wharfLadder.tideGap") ? "warm.backdoor" : "merrick.tidegap"
            default: desired = nil
            }
            let index = desired.flatMap { dest in choices.firstIndex { $0.destinationID == dest } } ?? 0
            _ = talk.selectChoice(at: index)
        }
        #expect(finished)
        state = talk.context.caseState
        if route == "warm" || route == "dry-true" {
            #expect(state.hasFlag("combat.e1.outcome.avoided"))
            #expect(!WharfLadderStory.requested(.e1, in: state))
            if route == "warm" {
                #expect(state.hasKnowledge("knowledge.wharfLadder.tideGap"))
                var wallet = 2400
                WharfLadderStory.settlePayment(in: &state, wallet: &wallet)
                #expect(wallet == 1800)
            }
        } else {
            #expect(WharfLadderStory.requested(.e1, in: state))
            #expect(WharfLadderStory.resolve(.e1, in: &state))
            #expect(state.hasEvidence("evidence.payTally.crateMark"))
        }
    }
    @Test func saveRoundTripResumesPendingFightAndUnreadAftermath() throws {
        var state = initial()
        state.setFlag("combat.a1.gate.trigger")
        var snapshot = SaveSnapshot(caseFlags: state.flags, caseCounters: state.counters)
        snapshot = try JSONDecoder().decode(SaveSnapshot.self, from: JSONEncoder().encode(snapshot))
        state = CaseState(caseID: state.caseID, flags: snapshot.caseFlags, counters: snapshot.caseCounters)
        WharfLadderStory.beginVisit(&state)
        #expect(state.counter(WharfLadderStory.visit) == 1)
        #expect(WharfLadderStory.resolve(.gate, in: &state))
        let restored = try JSONDecoder().decode(CaseState.self, from: JSONEncoder().encode(state))
        #expect(WharfLadderStory.pendingAftermath(in: restored) == .gate)
        #expect(WharfLadderStory.nextFloor(in: restored) == .lane)
    }
    @Test func skippingAtEveryTickClearsCrewAndCompletesOnce() {
        for encounter in WharfLadderStory.Encounter.allCases {
            let cinematic = WharfLadderStory.cinematic(for: encounter)
            let duration = cinematic.tracks[0].cues.map { $0.duration.ticks }.reduce(0, +)
            for tick in 15..<duration {
                var runner = CutsceneRunner()
                var commands = runner.begin(WharfLadderStory.cinematic(for: encounter), at: 0).commands
                commands += runner.advance(ticks: tick).commands
                let skipped = runner.skip(at: Double(tick) / 15)
                commands += skipped.commands
                #expect(skipped.completion == .skipped)
                #expect(commands.filter { $0.cue == .setFlag("wharf-ladder.clear-crew") }.count == 1)
                #expect(commands.contains { $0.cue == .setCutsceneMode(false) })
                #expect(runner.advance(ticks: 100).completion == nil)
            }
        }
    }
    @MainActor @Test func everyCrewFitsConnectedCellsOnTheRestoredPlates() throws {
        for (id, count) in [(WharfLadderStory.exterior, 2), (WharfLadderStory.interior, 3)] {
            let area = try AreaCatalogLoader.load(id)
            let map = area.makeNavigationMap()
            let start = id == WharfLadderStory.exterior
                ? try #require(area.regions.first?.approachPoint?.cgPoint)
                : try #require(area.spawnPoint(entrance: nil))
            // Include the integral endpoint observed after the live approach,
            // with the occupancy record still marked moving during its callback.
            let origins = [start, try #require(map.nearestWalkablePoint(to: CGPoint(x: area.worldBounds.midX, y: area.worldBounds.midY)))]
                + (id == WharfLadderStory.interior ? [CGPoint(x: 487, y: 364)] : [])
            for origin in origins {
                map.registerActor(id: "qa.player", kind: .player, at: origin)
                map.updateActor(id: "qa.player", position: origin, isMoving: true)
                let positions = WharfLadderStaging.positions(near: origin, count: count, navigation: map, ignoringActorID: "qa.player")
                #expect(positions.count == count)
                for point in positions {
                    let path = map.pathAvoidingActors(from: origin, to: point, identity: "qa.player")
                    #expect(map.searchMap.cell(for: path.destination ?? origin) == map.searchMap.cell(for: point))
                }
                #expect(map.occupancy.actors["qa.player"] != nil)
                map.unregisterActor(id: "qa.player")
            }
        }
    }
}
