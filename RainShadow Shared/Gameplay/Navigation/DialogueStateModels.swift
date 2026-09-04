import Foundation

// MARK: - Dialogue roadmap Phase 0 (state spine)
//
// Codable, SpriteKit-free value types for conditions, actions, and session context.
// Presenter owns DialogueSession (which holds DialogueRuntimeContext). Mid-conversation
// DialogueState is not yet part of SaveSnapshot. See Documentation/DialogueSystemRoadmap.md.

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
/// `queuedJournalFragments` accumulate for Phase 3 journal projection.
public struct CaseState: Codable, Equatable, Sendable {
    public var caseID: String
    public var flags: Set<String>
    public var knowledgeIDs: Set<String>
    public var evidenceIDs: Set<String>
    /// Dialogue-earned journal beats projected into the casebook via `JournalProjectionInput`.
    public var queuedJournalFragments: [QueuedJournalFragment]
    /// Integer case variables — the Infinity Engine's numeric `Global`, as opposed to
    /// the boolean intent `flags` already carries. Storage lands with the save envelope
    /// so the persisted shape changes once; the reading/writing DSL follows.
    public var counters: [String: Int]

    public init(
        caseID: String,
        flags: Set<String> = [],
        knowledgeIDs: Set<String> = [],
        evidenceIDs: Set<String> = [],
        queuedJournalFragments: [QueuedJournalFragment] = [],
        counters: [String: Int] = [:]
    ) {
        self.caseID = caseID
        self.flags = flags
        self.knowledgeIDs = knowledgeIDs
        self.evidenceIDs = evidenceIDs
        self.queuedJournalFragments = queuedJournalFragments
        self.counters = counters
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

    mutating func queueJournal(_ fragment: QueuedJournalFragment) {
        if let index = queuedJournalFragments.firstIndex(where: { $0.id == fragment.id }) {
            queuedJournalFragments[index] = fragment
        } else {
            queuedJournalFragments.append(fragment)
        }
    }

    /// Unset counters read as zero, matching IE, where an unassigned `Global` is 0
    /// rather than an error.
    func counter(_ id: String) -> Int {
        counters[id] ?? 0
    }

    /// IE `SetGlobal`.
    mutating func setCounter(_ id: String, to value: Int) {
        counters[id] = value
    }

    /// IE `IncrementGlobal`. Negative deltas subtract.
    mutating func addToCounter(_ id: String, _ delta: Int) {
        counters[id, default: 0] += delta
    }

    /// Reserved counter namespace behind IE's `NumTimesTalkedTo`. Keeping talk counts in
    /// `counters` rather than a parallel store means one save field, one merge path, and
    /// one place integrity reporting has to look.
    static func talkCounterID(_ ownerID: String) -> String {
        "talk.\(ownerID)"
    }

    func timesTalkedTo(_ ownerID: String) -> Int {
        counter(Self.talkCounterID(ownerID))
    }

    /// Bumped when a conversation **ends**, so `timesTalkedTo(x, atLeast: 1)` reads as
    /// "has talked to x before" with no off-by-one to explain. IE's own `DF_TALKCOUNT`
    /// timing varies between engine versions; this is the one that stays readable in
    /// authored JSON.
    mutating func noteTalk(with ownerID: String) {
        addToCounter(Self.talkCounterID(ownerID), 1)
    }
}

extension CaseState {
    /// Fold a finished conversation's state back into the owning session.
    ///
    /// A **seeded** result already contains everything this state held when the
    /// conversation opened, so it is authoritative: a flag the dialogue cleared must
    /// stay cleared. Unioning instead — which is what the shipped merge did — makes
    /// `clearCaseFlag` and `clearConversationFlag`'s case-level twin permanent no-ops.
    ///
    /// An **unseeded** result was built from a fresh `CaseState` and knows nothing of
    /// prior progress, so it can only add. That path exists for the legacy ad-hoc
    /// presenter wrapper and disappears once every call site seeds.
    ///
    /// Journal fragments always merge by id rather than being replaced wholesale:
    /// there is no action that retracts one, and `queueJournal` is already
    /// replace-by-id, so appending preserves both order and idempotence.
    func applying(_ result: CaseState, wasSeeded: Bool) -> CaseState {
        var merged = self
        if wasSeeded {
            merged.flags = result.flags
            merged.knowledgeIDs = result.knowledgeIDs
            merged.evidenceIDs = result.evidenceIDs
            merged.counters = result.counters
        } else {
            merged.flags.formUnion(result.flags)
            merged.knowledgeIDs.formUnion(result.knowledgeIDs)
            merged.evidenceIDs.formUnion(result.evidenceIDs)
            merged.counters.merge(result.counters) { _, dialogueValue in dialogueValue }
        }
        for fragment in result.queuedJournalFragments {
            merged.queueJournal(fragment)
        }
        if merged.caseID.isEmpty {
            merged.caseID = result.caseID
        }
        return merged
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

    /// Counters live on the case only — IE's LOCALS (per-actor) scope has no analogue
    /// here yet, and nothing has needed a conversation-scoped integer.
    func counter(_ id: String) -> Int {
        caseState.counter(id)
    }

    /// Choices on a node that pass Phase 1 conditions under this context.
    func availableChoices(from node: CaseDialogueNode) -> [CaseDialogueChoice] {
        CaseDialogueGraph.visibleChoices(node.choices, in: self)
    }
}

// MARK: - Empty Coat keys

/// Stable graph / flag ids for the Empty Coat intro.
enum EmptyCoatDialogueKeys {
    /// Graph id for the shipped office case introduction.
    static let graphID = "case.empty-coat.intro"
    /// Set when Voss picks a hard cynical push earlier; unlocks a later Press option.
    static let pressedHardOnStory = "empty-coat.dialogue.pressed-hard-on-story"
    /// Case flag: player retained Lila / opened The Empty Coat (acceptance choice).
    static let clientRetained = "empty-coat.case.client-retained"
    /// Queued chronology fragment id for P3 journal projection.
    static let clientRetainedJournalID = "chrono.client-retained"
    /// Queued chronology fragment when Press path is taken on the key triad.
    static let pressedHardJournalID = "chrono.pressed-hard"
}

// MARK: - Journal projection (Phase 3)

/// Read model for casebook projection: hotspots + dialogue-earned fragments/flags.
public struct JournalProjectionInput: Equatable, Sendable {
    public var inspectedHotspotIDs: Set<String>
    public var queuedJournalFragments: [QueuedJournalFragment]
    public var caseFlags: Set<String>

    public init(
        inspectedHotspotIDs: Set<String> = [],
        queuedJournalFragments: [QueuedJournalFragment] = [],
        caseFlags: Set<String> = []
    ) {
        self.inspectedHotspotIDs = inspectedHotspotIDs
        self.queuedJournalFragments = queuedJournalFragments
        self.caseFlags = caseFlags
    }

    public init(inspectedHotspotIDs: Set<String> = [], caseState: CaseState) {
        self.inspectedHotspotIDs = inspectedHotspotIDs
        self.queuedJournalFragments = caseState.queuedJournalFragments
        self.caseFlags = caseState.flags
    }
}
