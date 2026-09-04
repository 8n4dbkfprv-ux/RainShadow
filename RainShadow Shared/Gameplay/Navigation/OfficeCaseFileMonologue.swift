import Foundation

/// Stub second dialogue graph (Phase 4): short post-intro desk monologue.
///
/// Prose lives in `Resources/Dialogue/empty-coat.desk-monologue.dialogue.json`.
/// Proves the shared presenter/session can run a graph other than Empty Coat intro.
/// Classic BG monologue exception: Continue-only Voss interior pages.
enum OfficeCaseFileMonologue {
    static let graphID = "case.empty-coat.desk-monologue"
    static let startNodeID = "voss.desk.casefile.1"
    static let vossSpeaker = EmptyCoatCaseIntroduction.vossSpeaker
    static let vossPortrait = EmptyCoatCaseIntroduction.vossPortrait
    static let resourceName = "empty-coat.desk-monologue.dialogue"

    static var graph: DialogueGraph {
        loadedGraph
    }

    static var nodes: [CaseDialogueNode] {
        graph.nodes
    }

    private static let loadedGraph: DialogueGraph = {
        do {
            let graph = try DialogueGraphLoader.loadCached(
                id: graphID,
                resourceName: resourceName
            )
            assert(
                graph.startNodeID == startNodeID,
                "Desk monologue JSON start node mismatch: \(graph.startNodeID)"
            )
            return graph
        } catch {
            preconditionFailure("Failed to load office case-file monologue: \(error)")
        }
    }()
}
