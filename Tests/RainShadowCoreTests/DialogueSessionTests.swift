import Foundation
import Testing
@testable import RainShadowCore

struct DialogueSessionTests {
    @Test func emptyCoatGraphIntegrityViaDialogueGraph() {
        let graph = EmptyCoatCaseIntroduction.graph
        #expect(graph.id == EmptyCoatDialogueKeys.graphID)
        #expect(graph.startNodeID == EmptyCoatCaseIntroduction.startNodeID)
        let report = graph.integrityReport()
        #expect(report.isSound)
        #expect(CaseDialogueGraph.report(graph: graph) == report)
    }

    @Test func sessionStartsOnGraphStartAndContinueAdvances() {
        var session = DialogueSession(graph: EmptyCoatCaseIntroduction.graph)
        #expect(session.currentNodeID == EmptyCoatCaseIntroduction.startNodeID)
        #expect(session.currentNode?.isInteriorMonologue == true)
        #expect(session.visibleChoices.isEmpty)

        let result = session.advanceContinue()
        guard case .showing(let node) = result else {
            Issue.record("Expected showing after continue")
            return
        }
        #expect(node.id == "voss.monologue.2")
        #expect(session.currentNodeID == "voss.monologue.2")
    }

    @Test func selectChoiceAppliesActionsAndUnlocksPress() {
        let graph = EmptyCoatCaseIntroduction.graph
        var session = DialogueSession(graph: graph)
        // Jump to entrance choice beat.
        _ = session.jump(to: "lila.entrance.case")
        #expect(session.visibleChoices.count == 3)

        let cynicalIndex = session.visibleChoices.firstIndex { $0.tone == .cynicalSarcasm }
        #expect(cynicalIndex != nil)
        guard let cynicalIndex else { return }

        let step = session.selectChoice(at: cynicalIndex)
        guard case .showing = step else {
            Issue.record("Expected showing after cynical select")
            return
        }
        #expect(session.context.hasFlag(EmptyCoatDialogueKeys.pressedHardOnStory))

        _ = session.jump(to: "lila.triad.key")
        #expect(session.visibleChoices.count == 4)
        #expect(session.visibleChoices.contains { $0.destinationID == "lila.reply.press.gated" })
    }

    @Test func officeCaseFileMonologueReachesEnding() {
        let graph = OfficeCaseFileMonologue.graph
        #expect(graph.integrityReport().isSound)
        #expect(graph.integrityReport().reachesEnding)

        var session = DialogueSession(graph: graph)
        #expect(session.currentNodeID == OfficeCaseFileMonologue.startNodeID)

        var steps = 0
        while steps < 8 {
            steps += 1
            if session.currentNode?.endsDialogue == true {
                let end = session.advanceContinue()
                guard case .finished = end else {
                    Issue.record("Expected finished from endsDialogue node")
                    return
                }
                return
            }
            let result = session.advanceContinue()
            switch result {
            case .showing:
                continue
            case .finished:
                return
            case .invalid:
                Issue.record("Invalid step in desk monologue")
                return
            }
        }
        Issue.record("Desk monologue did not finish")
    }

    @Test func acceptancePathQueuesJournalThroughSession() {
        var session = DialogueSession(graph: EmptyCoatCaseIntroduction.graph)
        _ = session.jump(to: "lila.reply.good3.b")
        #expect(session.visibleChoices.count == 1)
        let result = session.selectChoice(at: 0)
        guard case .showing(let node) = result else {
            Issue.record("Expected plea after acceptance")
            return
        }
        #expect(node.id == "lila.plea")
        #expect(session.context.caseState.hasFlag(EmptyCoatDialogueKeys.clientRetained))
        #expect(
            session.context.caseState.queuedJournalFragments.contains {
                $0.id == EmptyCoatDialogueKeys.clientRetainedJournalID
            }
        )
    }
}
