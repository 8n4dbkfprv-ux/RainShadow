import Foundation
import Testing
@testable import RainShadowCore

/// The Infinity Engine's single most load-bearing dialogue mechanic: `FindFirstState`
/// scans states from index 0 and opens on the first whose state trigger passes. It is how
/// every NPC in Baldur's Gate says something different on your second visit. RainShadow
/// had one fixed `startNodeID`, so every conversation was frozen in time.
struct DialogueEntryScanTests {
    private func context(counters: [String: Int] = [:], flags: Set<String> = []) -> DialogueRuntimeContext {
        DialogueRuntimeContext(
            caseState: CaseState(caseID: "case.x", flags: flags, counters: counters),
            dialogueState: DialogueState(graphID: "g")
        )
    }

    private func retalkGraph() -> DialogueGraph {
        DialogueGraph(
            id: "g",
            startNodeID: "first",
            entryNodeIDs: ["again", "first"],
            nodes: [
                CaseDialogueNode(
                    id: "again",
                    speaker: "Lila",
                    text: "You again.",
                    endsDialogue: true,
                    entryWhen: [.timesTalkedTo(ownerID: "npc.lila-march", atLeast: 1)]
                ),
                CaseDialogueNode(id: "first", speaker: "Lila", text: "Mr Voss?", endsDialogue: true)
            ]
        )
    }

    @Test func firstTrueCandidateWins() {
        let graph = retalkGraph()
        #expect(graph.entryNodeID(in: context()) == "first")
        #expect(
            graph.entryNodeID(in: context(counters: [CaseState.talkCounterID("npc.lila-march"): 1]))
                == "again"
        )
    }

    /// Scan order is authored array order — the thing WeiDU's `WEIGHT` existed to fake.
    @Test func candidateOrderDecidesTiesNotNodeOrder() {
        let nodes = [
            CaseDialogueNode(id: "a", speaker: "S", text: "A", endsDialogue: true, entryWhen: [.hasFlag("f")]),
            CaseDialogueNode(id: "b", speaker: "S", text: "B", endsDialogue: true, entryWhen: [.hasFlag("f")]),
            CaseDialogueNode(id: "start", speaker: "S", text: "S", endsDialogue: true)
        ]
        let aFirst = DialogueGraph(id: "g", startNodeID: "start", entryNodeIDs: ["a", "b", "start"], nodes: nodes)
        let bFirst = DialogueGraph(id: "g", startNodeID: "start", entryNodeIDs: ["b", "a", "start"], nodes: nodes)

        #expect(aFirst.entryNodeID(in: context(flags: ["f"])) == "a")
        #expect(bFirst.entryNodeID(in: context(flags: ["f"])) == "b")
    }

    /// Every graph shipped before re-talk existed must open exactly where it always did.
    @Test func anEmptyCandidateListMeansStartNode() {
        let graph = DialogueGraph(
            id: "g",
            startNodeID: "only",
            nodes: [CaseDialogueNode(id: "only", speaker: "S", text: "T", endsDialogue: true)]
        )
        #expect(graph.entryNodeIDs.isEmpty)
        #expect(graph.entryNodeID(in: context()) == "only")
    }

    @Test func theSessionOpensOnTheScannedNode() {
        var session = DialogueSession(
            graph: retalkGraph(),
            context: context(counters: [CaseState.talkCounterID("npc.lila-march"): 2])
        )
        #expect(session.currentNodeID == "again")
        #expect(session.currentNode?.text == "You again.")
        #expect(session.advanceContinue() == .finished(caseState: session.context.caseState))
    }

    /// State triggers are consulted only when the conversation *starts*. Mid-graph a node
    /// is entered by its destination link, exactly as in DLG.
    @Test func entryConditionsAreIgnoredMidConversation() {
        let graph = DialogueGraph(
            id: "g",
            startNodeID: "start",
            nodes: [
                CaseDialogueNode(id: "start", speaker: "S", text: "Start", nextNodeID: "gated"),
                CaseDialogueNode(
                    id: "gated",
                    speaker: "S",
                    text: "Gated",
                    endsDialogue: true,
                    entryWhen: [.hasFlag("never-set")]
                )
            ]
        )
        var session = DialogueSession(graph: graph, context: context())
        #expect(session.currentNodeID == "start")
        #expect(session.advanceContinue() == .showing(graph.node(id: "gated")!))
    }

    /// A conversation already in progress keeps its node — the scan is a start-of-talk
    /// decision, not something that re-runs on every step.
    @Test func aLiveNodeSurvivesSessionConstruction() {
        var seeded = context(counters: [CaseState.talkCounterID("npc.lila-march"): 1])
        seeded.dialogueState.currentNodeID = "first"
        let session = DialogueSession(graph: retalkGraph(), context: seeded)
        #expect(session.currentNodeID == "first")
    }

    // MARK: - Authoring guards

    /// The entry fallback returns `startNodeID` unconditionally, so a gate there would
    /// never run. Silently ignoring it is exactly the trap entry scanning invites.
    @Test func gatingTheStartNodeIsRejected() {
        let graph = DialogueGraph(
            id: "g",
            startNodeID: "start",
            nodes: [
                CaseDialogueNode(
                    id: "start",
                    speaker: "S",
                    text: "T",
                    endsDialogue: true,
                    entryWhen: [.hasFlag("f")]
                )
            ]
        )
        #expect(throws: DialogueGraphLoaderError.conditionalStartNode(graphID: "g", startNodeID: "start")) {
            try graph.validateAuthoring()
        }
        #expect(!graph.integrityReport().startNodeIsUnconditional)
        #expect(!graph.integrityReport().isSound)
    }

    @Test func anEntryCandidateThatDoesNotExistIsRejected() {
        let graph = DialogueGraph(
            id: "g",
            startNodeID: "start",
            entryNodeIDs: ["ghost", "start"],
            nodes: [CaseDialogueNode(id: "start", speaker: "S", text: "T", endsDialogue: true)]
        )
        #expect(throws: DialogueGraphLoaderError.missingEntryNode(graphID: "g", entryNodeID: "ghost")) {
            try graph.validateAuthoring()
        }
        #expect(graph.integrityReport().missingEntryNodeIDs == ["ghost"])
    }

    /// Reachability seeds from every candidate, not just the start node — otherwise a
    /// whole alternate opening reports as orphaned.
    @Test func alternateOpeningsAreNotOrphans() {
        let report = retalkGraph().integrityReport()
        #expect(report.orphanNodeIDs.isEmpty)
        #expect(report.reachableNodeIDs == ["again", "first"])
        #expect(report.isSound)
    }
}

// MARK: - Talk counters

extension DialogueEntryScanTests {
    /// Counting on conversation *end* means `atLeast: 1` reads as "has talked before",
    /// with no off-by-one to explain to an author.
    @Test func talkCountsAccumulateInTheReservedCounterNamespace() {
        var state = CaseState(caseID: "case.x")
        #expect(state.timesTalkedTo("npc.lila-march") == 0)

        state.noteTalk(with: "npc.lila-march")
        #expect(state.timesTalkedTo("npc.lila-march") == 1)
        #expect(state.counters["talk.npc.lila-march"] == 1)

        state.noteTalk(with: "npc.lila-march")
        #expect(state.timesTalkedTo("npc.lila-march") == 2)
        #expect(state.timesTalkedTo("npc.someone-else") == 0)
    }

    @Test func timesTalkedToConditionReadsThatNamespace() {
        var state = CaseState(caseID: "case.x")
        state.noteTalk(with: "office.window")
        let ctx = DialogueRuntimeContext(caseState: state, dialogueState: DialogueState(graphID: "g"))

        #expect(DialogueCondition.timesTalkedTo(ownerID: "office.window", atLeast: 1).isSatisfied(by: ctx))
        #expect(!DialogueCondition.timesTalkedTo(ownerID: "office.window", atLeast: 2).isSatisfied(by: ctx))
        #expect(
            DialogueCondition.timesTalkedTo(ownerID: "office.window", atLeast: 1).referencedIDs
                == ["talk.office.window"]
        )
    }

    @Test func talkConditionsRoundTripThroughJSON() throws {
        let condition = DialogueCondition.timesTalkedTo(ownerID: "npc.lila-march", atLeast: 2)
        let data = try JSONEncoder().encode(condition)
        #expect(try JSONDecoder().decode(DialogueCondition.self, from: data) == condition)
    }
}
