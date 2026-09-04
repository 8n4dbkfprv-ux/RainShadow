import Foundation
import Testing
@testable import RainShadowCore

/// A DLG transition can name another file plus a state index — `EXTERN`. RainShadow's
/// destinations resolved only inside the current graph, so a conversation could never
/// hand off. GemRB keeps the conversation alive across the jump; so does this.
struct DialogueCrossGraphTests {
    private var lobby: DialogueGraph {
        DialogueGraph(
            id: "case.lobby",
            startNodeID: "start",
            nodes: [
                CaseDialogueNode(
                    id: "start",
                    speaker: "Clerk",
                    text: "She's upstairs.",
                    choices: [
                        CaseDialogueChoice(
                            text: "Go up.",
                            destinationID: "greeting",
                            destinationGraphID: "case.office",
                            onSelect: [.setConversationFlag("asked-the-clerk")]
                        )
                    ]
                )
            ]
        )
    }

    private var office: DialogueGraph {
        DialogueGraph(
            id: "case.office",
            startNodeID: "greeting",
            nodes: [
                CaseDialogueNode(id: "greeting", speaker: "Lila", text: "You took your time.", endsDialogue: true)
            ]
        )
    }

    private func session() -> DialogueSession {
        var session = DialogueSession(
            graph: lobby,
            context: DialogueRuntimeContext(
                caseState: CaseState(caseID: "case.x"),
                dialogueState: DialogueState(graphID: "case.lobby")
            )
        )
        session.catalog = DialogueGraphCatalog(graphs: [lobby, office])
        return session
    }

    @Test func aChoiceCanJumpToAnotherGraph() {
        var session = session()
        let result = session.selectChoice(at: 0)

        #expect(result == .showing(office.node(id: "greeting")!))
        #expect(session.graph.id == "case.office")
        #expect(session.currentNodeID == "greeting")
        #expect(session.context.dialogueState.graphID == "case.office")
    }

    /// In IE an EXTERN is still the same conversation, just a different file — the talk
    /// does not restart, so conversation-local state has to survive.
    @Test func conversationStateSurvivesTheJump() {
        var session = session()
        _ = session.selectChoice(at: 0)

        #expect(session.context.dialogueState.hasConversationFlag("asked-the-clerk"))
        #expect(session.context.dialogueState.choiceHistory == ["greeting"])
    }

    @Test func theNewGraphsNodesAreWalkableAfterTheJump() {
        var session = session()
        _ = session.selectChoice(at: 0)
        #expect(session.advanceContinue() == .finished(caseState: session.context.caseState))
    }

    /// An unreachable target ends the conversation rather than wedging the panel on a
    /// node that does not exist — the same shape as an unresolvable in-graph destination.
    @Test func anUnresolvableGraphEndsTheConversation() {
        var session = DialogueSession(graph: lobby)
        session.catalog = DialogueGraphCatalog(graphs: [lobby])

        if case .finished = session.selectChoice(at: 0) {
            // expected
        } else {
            Issue.record("expected an unresolvable EXTERN to finish the conversation")
        }
    }

    // MARK: - Catalog integrity

    @Test func catalogReportResolvesCrossGraphLinks() {
        let report = CaseDialogueGraph.report(catalog: DialogueGraphCatalog(graphs: [lobby, office]))
        #expect(report.missingDestinationGraphIDs.isEmpty)
        #expect(report.missingCrossGraphNodeIDs.isEmpty)
        #expect(report.isSound)
    }

    @Test func catalogReportNamesAMissingTargetGraph() {
        let report = CaseDialogueGraph.report(catalog: DialogueGraphCatalog(graphs: [lobby]))
        #expect(report.missingDestinationGraphIDs == ["case.lobby:start->case.office:greeting"])
        #expect(!report.isSound)
    }

    /// A graph whose only exit is an EXTERN cannot reach an ending on its own, and is not
    /// broken for it — the catalog follows the link. Per-graph `isSound` still says no,
    /// which is why the catalog checks `isStructurallySound` instead.
    @Test func aHandoffGraphIsSoundOnlyInCatalogTerms() {
        #expect(!lobby.integrityReport().reachesEnding)
        #expect(!lobby.integrityReport().isSound)
        #expect(lobby.integrityReport().isStructurallySound)

        let report = CaseDialogueGraph.report(catalog: DialogueGraphCatalog(graphs: [lobby, office]))
        #expect(report.graphIDsWithNoReachableEnding.isEmpty)
        #expect(report.isSound)
    }

    /// Two graphs that only hand off to each other can never close a conversation.
    @Test func aCycleWithNoEndingIsReported() {
        let a = DialogueGraph(
            id: "a",
            startNodeID: "n",
            nodes: [CaseDialogueNode(
                id: "n", speaker: "S", text: "T",
                choices: [CaseDialogueChoice(text: "→b", destinationID: "n", destinationGraphID: "b")]
            )]
        )
        let b = DialogueGraph(
            id: "b",
            startNodeID: "n",
            nodes: [CaseDialogueNode(
                id: "n", speaker: "S", text: "T",
                choices: [CaseDialogueChoice(text: "→a", destinationID: "n", destinationGraphID: "a")]
            )]
        )

        let report = CaseDialogueGraph.report(catalog: DialogueGraphCatalog(graphs: [a, b]))
        #expect(report.graphIDsWithNoReachableEnding == ["a", "b"])
        #expect(!report.isSound)
    }

    @Test func catalogReportNamesAMissingTargetNode() {
        let strangerOffice = DialogueGraph(
            id: "case.office",
            startNodeID: "elsewhere",
            nodes: [CaseDialogueNode(id: "elsewhere", speaker: "Lila", text: "…", endsDialogue: true)]
        )
        let report = CaseDialogueGraph.report(
            catalog: DialogueGraphCatalog(graphs: [lobby, strangerOffice])
        )
        #expect(report.missingCrossGraphNodeIDs == ["case.lobby:start->case.office:greeting"])
        #expect(!report.isSound)
    }

    /// Per-graph integrity must not report a cross-graph destination as a dangling link —
    /// it is the catalog's job to resolve it.
    @Test func singleGraphIntegrityIgnoresCrossGraphDestinations() {
        let report = lobby.integrityReport()
        #expect(report.missingDestinationIDs.isEmpty)
    }

    @Test func crossGraphChoicesRoundTripThroughJSON() throws {
        let choice = CaseDialogueChoice(
            text: "Go up.",
            destinationID: "greeting",
            destinationGraphID: "case.office"
        )
        let data = try JSONEncoder().encode(choice)
        #expect(try JSONDecoder().decode(CaseDialogueChoice.self, from: data) == choice)
        // Absent on an in-graph choice, so shipped files encode byte-identically.
        let plain = CaseDialogueChoice(text: "Stay.", destinationID: "start")
        let plainJSON = String(data: try JSONEncoder().encode(plain), encoding: .utf8) ?? ""
        #expect(!plainJSON.contains("destinationGraphID"))
    }
}
