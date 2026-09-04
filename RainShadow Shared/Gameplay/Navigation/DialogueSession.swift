import Foundation

// MARK: - Dialogue roadmap Phase 4 (multi-graph)

/// Authored conversation package: id + start + nodes.
struct DialogueGraph: Equatable, Codable, Sendable {
    let id: String
    /// Guaranteed fallback and the last link in the entry chain. Its node must be
    /// ungated — see `entryNodeID(in:)`.
    let startNodeID: String
    /// Ordered entry candidates, scanned first-true (IE `FindFirstState`). Empty means
    /// "just `startNodeID`", which is every graph shipped before re-talk existed.
    let entryNodeIDs: [String]
    let nodes: [CaseDialogueNode]

    enum CodingKeys: String, CodingKey {
        case id
        case startNodeID
        case entryNodeIDs
        case nodes
    }

    init(
        id: String,
        startNodeID: String,
        entryNodeIDs: [String] = [],
        nodes: [CaseDialogueNode]
    ) {
        self.id = id
        self.startNodeID = startNodeID
        self.entryNodeIDs = entryNodeIDs
        self.nodes = nodes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        startNodeID = try container.decode(String.self, forKey: .startNodeID)
        entryNodeIDs = try container.decodeIfPresent([String].self, forKey: .entryNodeIDs) ?? []
        nodes = try container.decode([CaseDialogueNode].self, forKey: .nodes)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(startNodeID, forKey: .startNodeID)
        if !entryNodeIDs.isEmpty {
            try container.encode(entryNodeIDs, forKey: .entryNodeIDs)
        }
        try container.encode(nodes, forKey: .nodes)
    }

    /// Which node opens the conversation — the Infinity Engine's `FindFirstState`.
    ///
    /// IE scans states from index 0 and takes the first whose state trigger passes; a
    /// DLG has no entry list, so every state is a candidate and WeiDU's `WEIGHT` exists
    /// purely to reorder that scan. RainShadow states the candidates outright: scan
    /// `entryNodeIDs` in authored order, take the first whose `entryWhen` passes, else
    /// fall back to `startNodeID`.
    ///
    /// The fallback is unconditional, which is why `startNodeID`'s node must carry no
    /// `entryWhen` — a condition there would be silently ignored. `validateAuthoring()`
    /// rejects that, and `CaseDialogueGraph.report` reports it.
    func entryNodeID(in context: DialogueRuntimeContext) -> String {
        for candidate in entryNodeIDs {
            guard let node = node(id: candidate) else { continue }
            if node.entryWhen.allSatisfy({ $0.isSatisfied(by: context) }) {
                return candidate
            }
        }
        return startNodeID
    }

    /// Node lookup, last-wins on a duplicate id.
    ///
    /// This used to be `Dictionary(uniqueKeysWithValues:)`, which **traps** — a typo'd
    /// id in authored JSON crashed the process instead of reporting an authoring error.
    /// Duplicates are now rejected at load (`DialogueGraphLoaderError.duplicateNodeID`)
    /// and surfaced by `CaseDialogueGraph.report`, so the runtime path can stay total.
    var nodesByID: [String: CaseDialogueNode] {
        var index: [String: CaseDialogueNode] = [:]
        index.reserveCapacity(nodes.count)
        for node in nodes {
            index[node.id] = node
        }
        return index
    }

    /// Ids that appear more than once, in first-seen order. Empty for a sound graph.
    var duplicateNodeIDs: [String] {
        var seen: Set<String> = []
        var duplicates: [String] = []
        for node in nodes where !seen.insert(node.id).inserted {
            if !duplicates.contains(node.id) {
                duplicates.append(node.id)
            }
        }
        return duplicates
    }

    func node(id: String) -> CaseDialogueNode? {
        nodesByID[id]
    }

    func integrityReport() -> CaseDialogueGraph.IntegrityReport {
        CaseDialogueGraph.report(nodes: nodes, startID: startNodeID, entryNodeIDs: entryNodeIDs)
    }

    /// Load-time authoring checks shared by both graph-construction paths
    /// (`DialogueGraphLoader.validate` and `DialogueStringTable.resolve`).
    func validateAuthoring() throws {
        if nodes.isEmpty {
            throw DialogueGraphLoaderError.emptyGraph(id: id)
        }
        if node(id: startNodeID) == nil {
            throw DialogueGraphLoaderError.missingStartNode(graphID: id, startNodeID: startNodeID)
        }
        if let duplicate = duplicateNodeIDs.first {
            throw DialogueGraphLoaderError.duplicateNodeID(graphID: id, nodeID: duplicate)
        }
        for candidate in entryNodeIDs where node(id: candidate) == nil {
            throw DialogueGraphLoaderError.missingEntryNode(graphID: id, entryNodeID: candidate)
        }
        if let start = node(id: startNodeID), !start.entryWhen.isEmpty {
            // The fallback fires regardless, so a gate here never runs. Authoring one is
            // a silent no-op, which is exactly the class of bug entry scanning invites.
            throw DialogueGraphLoaderError.conditionalStartNode(graphID: id, startNodeID: startNodeID)
        }
        for node in nodes {
            for condition in node.choices.flatMap(\.conditions) + node.entryWhen
            where condition.depth > DialogueCondition.maximumNestingDepth {
                throw DialogueGraphLoaderError.conditionTooDeep(
                    graphID: id,
                    nodeID: node.id,
                    depth: condition.depth,
                    limit: DialogueCondition.maximumNestingDepth
                )
            }
        }
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
    /// Built once per graph. `DialogueGraph.nodesByID` rebuilds the whole dictionary on
    /// every call, and `resolve(nodeID:)` runs on every step of every conversation.
    private var nodeIndex: [String: CaseDialogueNode]
    var context: DialogueRuntimeContext
    /// What the player has already read in this conversation (BG:EE scroll-back).
    /// Presentation state, not game state — never merged into `CaseState`, never saved.
    private(set) var transcript = DialogueTranscript()
    /// Speaker attributed to the player's own replies in the transcript. IE transition
    /// text is the PC talking, so it must not be filed under the NPC's name.
    var playerSpeaker: String = "Harlan Voss"
    /// Speaker string that reads as a card rather than a line (e.g. "Case opened").
    var titleSpeaker: String?
    /// Graphs a cross-graph choice may jump to (IE EXTERN). The walker never loads
    /// anything itself — whoever starts the conversation supplies the reachable set.
    var catalog: DialogueGraphCatalog = .empty

    var currentNodeID: String? {
        context.dialogueState.currentNodeID
    }

    var currentNode: CaseDialogueNode? {
        guard let id = currentNodeID else { return nil }
        return nodeIndex[id]
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
        self.nodeIndex = graph.nodesByID
        if var seeded = context {
            if seeded.dialogueState.graphID.isEmpty {
                seeded.dialogueState.graphID = graph.id
            }
            if seeded.dialogueState.currentNodeID == nil
                || graph.node(id: seeded.dialogueState.currentNodeID ?? "") == nil
            {
                // No live node means this is the *start* of a conversation, which is
                // the only moment IE consults state triggers.
                seeded.dialogueState.currentNodeID = graph.entryNodeID(in: seeded)
            }
            self.context = seeded
        } else {
            var fresh = DialogueRuntimeContext(
                caseState: CaseState(caseID: EmptyCoatJournalContent.caseID),
                dialogueState: DialogueState(graphID: graph.id)
            )
            fresh.dialogueState.currentNodeID = graph.entryNodeID(in: fresh)
            self.context = fresh
        }
    }

    /// Sync dialogue state to the current node before presentation (no side effects on
    /// game state) and record it in the transcript.
    ///
    /// Idempotent: the presenter re-shows the same node on every layout rebuild and on
    /// resume from a cutscene, and neither may duplicate a line in the scroll-back.
    mutating func noteCurrentNodeShown() {
        guard let id = currentNodeID, let node = nodeIndex[id] else { return }
        context.dialogueState.advance(to: id)
        transcript.appendNode(node, isTitle: titleSpeaker.map { node.speaker == $0 } ?? false)
    }

    /// Player selected a visible choice (index into `visibleChoices`).
    /// Applies `onSelect`, records history, advances to destination.
    mutating func selectChoice(at index: Int) -> DialogueStepResult {
        let choices = visibleChoices
        guard choices.indices.contains(index) else { return .invalid }
        let choice = choices[index]
        // Echo the committed reply before the graph moves, so the scroll-back reads as
        // the conversation actually happened.
        transcript.appendPlayerReply(
            choice,
            speaker: playerSpeaker,
            fromNodeID: currentNodeID ?? ""
        )
        DialogueActionRuntime.apply(choice.onSelect, to: &context)
        context.dialogueState.recordChoice(destinationID: choice.destinationID)
        if let targetGraphID = choice.destinationGraphID, targetGraphID != graph.id {
            return switchGraph(to: targetGraphID, nodeID: choice.destinationID)
        }
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

    /// IE EXTERN. The conversation continues — `conversationFlags` and `choiceHistory`
    /// survive the jump, because in the Infinity Engine an EXTERN is still the same talk,
    /// just a different file. Only the graph and its node index change.
    private mutating func switchGraph(to graphID: String, nodeID: String) -> DialogueStepResult {
        guard let target = catalog.graph(id: graphID) else {
            // End the conversation rather than wedging on a node that does not exist —
            // the same degradation an unresolvable in-graph destination already gets.
            //
            // Deliberately not an `assertionFailure`: an unresolvable link is an authoring
            // error, and `CaseDialogueGraph.report(catalog:)` catches it in tests over the
            // shipped resources, which is both earlier and stricter than a debug trap that
            // only fires if a player happens to pick that reply.
            return .finished(caseState: context.caseState)
        }
        graph = target
        nodeIndex = target.nodesByID
        context.dialogueState.graphID = target.id
        return resolve(nodeID: nodeID)
    }

    private mutating func resolve(nodeID: String) -> DialogueStepResult {
        guard let node = nodeIndex[nodeID] else {
            return .finished(caseState: context.caseState)
        }
        context.dialogueState.currentNodeID = nodeID
        return .showing(node)
    }
}

extension CaseDialogueGraph {
    static func report(graph: DialogueGraph) -> IntegrityReport {
        report(nodes: graph.nodes, startID: graph.startNodeID, entryNodeIDs: graph.entryNodeIDs)
    }
}
