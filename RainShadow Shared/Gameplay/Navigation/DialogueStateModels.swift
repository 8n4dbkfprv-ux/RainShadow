import Foundation

// MARK: - Dialogue roadmap Phase 0 (state spine)
//
// Codable, SpriteKit-free value types so Phase 1 conditions and Phase 2 actions
// have a shared context to read and write. See Documentation/DialogueSystemRoadmap.md.
// Not wired to CaseIntroductionPresenter or SaveSnapshot yet (P0 exit criteria).

/// Stable string key for world / case / dialogue flags.
///
/// Storage on `CaseState` / `DialogueState` uses raw strings; wrap constants in
/// `WorldFlag` at authoring sites for architecture §14.1 name parity.
struct WorldFlag: RawRepresentable, Hashable, Codable, Sendable {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    init(_ rawValue: String) {
        self.rawValue = rawValue
    }
}

/// Persistent (or session-long) state for one investigation case.
///
/// Evidence and knowledge are id sets only — full records come later.
/// Flags feed Phase 1 `DialogueCondition` evaluation.
struct CaseState: Codable, Equatable, Sendable {
    var caseID: String
    var flags: Set<String>
    var knowledgeIDs: Set<String>
    var evidenceIDs: Set<String>

    init(
        caseID: String,
        flags: Set<String> = [],
        knowledgeIDs: Set<String> = [],
        evidenceIDs: Set<String> = []
    ) {
        self.caseID = caseID
        self.flags = flags
        self.knowledgeIDs = knowledgeIDs
        self.evidenceIDs = evidenceIDs
    }

    func hasFlag(_ id: String) -> Bool {
        flags.contains(id)
    }

    func hasFlag(_ flag: WorldFlag) -> Bool {
        hasFlag(flag.rawValue)
    }

    mutating func setFlag(_ id: String) {
        flags.insert(id)
    }

    mutating func setFlag(_ flag: WorldFlag) {
        setFlag(flag.rawValue)
    }

    mutating func clearFlag(_ id: String) {
        flags.remove(id)
    }

    mutating func clearFlag(_ flag: WorldFlag) {
        clearFlag(flag.rawValue)
    }

    func hasKnowledge(_ id: String) -> Bool {
        knowledgeIDs.contains(id)
    }

    mutating func grantKnowledge(_ id: String) {
        knowledgeIDs.insert(id)
    }

    func hasEvidence(_ id: String) -> Bool {
        evidenceIDs.contains(id)
    }

    mutating func grantEvidence(_ id: String) {
        evidenceIDs.insert(id)
    }
}

/// In-conversation walker state: which graph/node is live, plus talk-local flags.
///
/// Conversation flags do not leak into `CaseState` unless a later action copies them.
/// Mid-conversation save is not required for M-dialogue-A (roadmap default: no).
struct DialogueState: Codable, Equatable, Sendable {
    var graphID: String
    var currentNodeID: String?
    /// Flags local to this conversation instance.
    var conversationFlags: Set<String>
    /// Trail of chosen destination node ids (for tests and later re-talk).
    var choiceHistory: [String]

    init(
        graphID: String,
        currentNodeID: String? = nil,
        conversationFlags: Set<String> = [],
        choiceHistory: [String] = []
    ) {
        self.graphID = graphID
        self.currentNodeID = currentNodeID
        self.conversationFlags = conversationFlags
        self.choiceHistory = choiceHistory
    }

    func hasConversationFlag(_ id: String) -> Bool {
        conversationFlags.contains(id)
    }

    func hasConversationFlag(_ flag: WorldFlag) -> Bool {
        hasConversationFlag(flag.rawValue)
    }

    mutating func setConversationFlag(_ id: String) {
        conversationFlags.insert(id)
    }

    mutating func setConversationFlag(_ flag: WorldFlag) {
        setConversationFlag(flag.rawValue)
    }

    mutating func clearConversationFlag(_ id: String) {
        conversationFlags.remove(id)
    }

    mutating func clearConversationFlag(_ flag: WorldFlag) {
        clearConversationFlag(flag.rawValue)
    }

    /// Move the walker to a new node without recording a player choice.
    mutating func advance(to nodeID: String) {
        currentNodeID = nodeID
    }

    /// Record a selected transition destination and advance to it.
    mutating func recordChoice(destinationID: String) {
        choiceHistory.append(destinationID)
        currentNodeID = destinationID
    }
}

/// Mutable bag passed into condition evaluation (P1) and action application (P2).
///
/// Flag reads are a **union**: true if either conversation-local or case state holds the id.
/// Writers choose the layer in Phase 2 (`setFlag` on case vs conversation).
struct DialogueRuntimeContext: Equatable, Sendable {
    var caseState: CaseState
    var dialogueState: DialogueState

    init(caseState: CaseState, dialogueState: DialogueState) {
        self.caseState = caseState
        self.dialogueState = dialogueState
    }

    /// True if the flag is set on conversation state or case state.
    func hasFlag(_ id: String) -> Bool {
        dialogueState.hasConversationFlag(id) || caseState.hasFlag(id)
    }

    func hasFlag(_ flag: WorldFlag) -> Bool {
        hasFlag(flag.rawValue)
    }

    func hasEvidence(_ id: String) -> Bool {
        caseState.hasEvidence(id)
    }

    func hasKnowledge(_ id: String) -> Bool {
        caseState.hasKnowledge(id)
    }
}

// MARK: - Empty Coat keys (reserved for later phases)

/// Stable graph / flag ids for the Empty Coat intro. Unused by runtime until P1/P2.
enum EmptyCoatDialogueKeys {
    /// Graph id for the shipped office case introduction.
    static let graphID = "case.empty-coat.intro"
}
