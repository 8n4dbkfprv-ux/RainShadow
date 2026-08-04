import Foundation

/// Stub second dialogue graph (Phase 4): short post-intro desk monologue.
///
/// Proves the shared presenter/session can run a graph other than Empty Coat intro.
/// Classic BG monologue exception: Continue-only Voss interior pages.
enum OfficeCaseFileMonologue {
    static let graphID = "case.empty-coat.desk-monologue"
    static let startNodeID = "voss.desk.casefile.1"
    static let vossSpeaker = EmptyCoatCaseIntroduction.vossSpeaker
    static let vossPortrait = EmptyCoatCaseIntroduction.vossPortrait

    static var graph: DialogueGraph {
        DialogueGraph(id: graphID, startNodeID: startNodeID, nodes: nodes)
    }

    static var nodes: [CaseDialogueNode] {
        [
            CaseDialogueNode(
                id: "voss.desk.casefile.1",
                speaker: vossSpeaker,
                text: """
                The key sits on the blotter like it owns the place. Brass, small teeth, no hotel tag—just machine oil and the smell of a river that already told one lie tonight.
                """,
                portraitName: vossPortrait,
                nextNodeID: "voss.desk.casefile.2",
                isInteriorMonologue: true
            ),
            CaseDialogueNode(
                id: "voss.desk.casefile.2",
                speaker: vossSpeaker,
                text: """
                Empty Coat is open. Harborpoint is not. Tomorrow I start measuring the gap between a police drowning and a sister who still buys umbrellas for a woman the river was supposed to keep.
                """,
                portraitName: vossPortrait,
                nextNodeID: "voss.desk.casefile.end",
                isInteriorMonologue: true
            ),
            CaseDialogueNode(
                id: "voss.desk.casefile.end",
                speaker: vossSpeaker,
                text: """
                File the night. Work the morning. If the gray overcoat comes looking for the key, he can take a number.
                """,
                portraitName: vossPortrait,
                endsDialogue: true,
                isInteriorMonologue: true
            )
        ]
    }
}
