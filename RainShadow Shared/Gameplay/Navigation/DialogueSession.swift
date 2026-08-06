import Foundation

// MARK: - Dialogue roadmap Phase 4 (multi-graph)

/// Authored conversation package: id + start + nodes.
struct DialogueGraph: Equatable, Codable, Sendable {
    let id: String
    let startNodeID: String
    let nodes: [CaseDialogueNode]

    var nodesByID: [String: CaseDialogueNode] {
        Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })
    }

    func node(id: String) -> CaseDialogueNode? {
        nodesByID[id]
    }

    func integrityReport() -> CaseDialogueGraph.IntegrityReport {
        CaseDialogueGraph.report(nodes: nodes, startID: startNodeID)
    }
}

/// Result of a pure session step (no SpriteKit).
enum DialogueStepResult: Equatable, Sendable {
    case showing(CaseDialogueNode)
    case finished(caseState: CaseState)
    case invalid
}

/// Pure dialogue walker: conditions, actions, and node advance.
/// The presenter is a view over this session.
struct DialogueSession: Equatable, Sendable {
    private(set) var graph: DialogueGraph
    var context: DialogueRuntimeContext

    var currentNodeID: String? {
        context.dialogueState.currentNodeID
    }

    var currentNode: CaseDialogueNode? {
        guard let id = currentNodeID else { return nil }
        return graph.node(id: id)
    }

    var visibleChoices: [CaseDialogueChoice] {
        guard let node = currentNode else { return [] }
        return CaseDialogueGraph.visibleChoices(node.choices, in: context)
    }

    var isSoftStuck: Bool {
        guard let node = currentNode else { return true }
        return CaseDialogueGraph.isSoftStuck(node: node, visibleChoices: visibleChoices)
    }

    init(graph: DialogueGraph, context: DialogueRuntimeContext? = nil) {
        self.graph = graph
        if var seeded = context {
            if seeded.dialogueState.graphID.isEmpty {
                seeded.dialogueState.graphID = graph.id
            }
            if seeded.dialogueState.currentNodeID == nil
                || graph.node(id: seeded.dialogueState.currentNodeID ?? "") == nil
            {
                seeded.dialogueState.currentNodeID = graph.startNodeID
            }
            self.context = seeded
        } else {
            self.context = DialogueRuntimeContext(
                caseState: CaseState(caseID: EmptyCoatJournalContent.caseID),
                dialogueState: DialogueState(
                    graphID: graph.id,
                    currentNodeID: graph.startNodeID
                )
            )
        }
    }

    /// Sync dialogue state to the current node before presentation (no side effects).
    mutating func noteCurrentNodeShown() {
        guard let id = currentNodeID else { return }
        context.dialogueState.advance(to: id)
    }

    /// Player selected a visible choice (index into `visibleChoices`).
    /// Applies `onSelect`, records history, advances to destination.
    mutating func selectChoice(at index: Int) -> DialogueStepResult {
        let choices = visibleChoices
        guard choices.indices.contains(index) else { return .invalid }
        let choice = choices[index]
        DialogueActionRuntime.apply(choice.onSelect, to: &context)
        context.dialogueState.recordChoice(destinationID: choice.destinationID)
        return resolve(nodeID: choice.destinationID)
    }

    /// Continue / linear advance when there are no visible choices.
    /// Does not apply choice actions.
    mutating func advanceContinue() -> DialogueStepResult {
        guard let node = currentNode else { return .invalid }
        if !visibleChoices.isEmpty {
            return .invalid
        }
        if node.endsDialogue {
            return .finished(caseState: context.caseState)
        }
        guard let next = node.nextNodeID else {
            return .finished(caseState: context.caseState)
        }
        context.dialogueState.advance(to: next)
        return resolve(nodeID: next)
    }

    /// Force jump (e.g. after cutscene). No actions.
    mutating func jump(to nodeID: String) -> DialogueStepResult {
        context.dialogueState.advance(to: nodeID)
        return resolve(nodeID: nodeID)
    }

    private mutating func resolve(nodeID: String) -> DialogueStepResult {
        guard let node = graph.node(id: nodeID) else {
            return .finished(caseState: context.caseState)
        }
        context.dialogueState.currentNodeID = nodeID
        return .showing(node)
    }
}

extension CaseDialogueGraph {
    static func report(graph: DialogueGraph) -> IntegrityReport {
        report(nodes: graph.nodes, startID: graph.startNodeID)
    }
}
