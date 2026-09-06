import Foundation

/// Authoring temperament triad for major response beats.
/// Not shown in UI — players read the line; tone is for writers, branching, and tests.
/// Intention is the system. These names are the feel of the line, not a morality meter.
///
/// JSON uses case names (`warm`, `dry`, `sharp`). Display labels stay on `displayLabel`.
enum DialogueTone: String, Equatable, CaseIterable, Codable, Sendable {
    case warm
    case dry
    case sharp

    /// Writer-facing label (not player UI).
    var displayLabel: String {
        switch self {
        case .warm: "Warm"
        case .dry: "Dry"
        case .sharp: "Sharp"
        }
    }
}

/// Writer-facing dialogue approach tags (GDD §7.5). Author method, not player UI.
/// Complements writer-only `DialogueTone`; does not encode morality meters.
/// Baldur’s Gate replies are numbered prose — do not paint these on the row.
enum DialogueIntention: String, Equatable, CaseIterable, Codable, Sendable {
    case open
    case press
    case feign
    case trade
    case observe
    case leave

    /// Writer-facing label (not player UI).
    var displayLabel: String {
        switch self {
        case .open: "Open"
        case .press: "Press"
        case .feign: "Feign"
        case .trade: "Trade"
        case .observe: "Observe"
        case .leave: "Leave"
        }
    }
}

// MARK: - Phase 2 transition actions

/// What a dialogue-earned casebook fragment *is*.
///
/// The Infinity Engine types journal writes with DLG transition bits 6/7/8 — unsolved
/// quest, plain note, solved quest. RainShadow's `kind` was a free string, so
/// `"chronolgy"` was a silent no-op that landed the beat in the default bucket.
///
/// `quest` / `questDone` exist to name the IE shape; nothing writes them yet, and the
/// *status* transition between them waits until there are quests to mark solved.
public enum JournalEntryKind: String, Codable, Equatable, Sendable, CaseIterable {
    /// A dated beat in the case log.
    case chronology
    /// A thread worth pulling.
    case lead
    /// An observation with no thread attached (IE journal note).
    case note
    case quest
    case questDone

    /// Unknown kinds read as `.note` rather than throwing. A save or resource written by
    /// a newer build must degrade to "a note we cannot classify", not brick the casebook.
    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = JournalEntryKind(rawValue: raw) ?? .note
    }
}

/// Dialogue-earned journal payload. Projected into the casebook in Phase 3.
public struct QueuedJournalFragment: Codable, Equatable, Sendable {
    public var id: String
    public var kind: JournalEntryKind
    public var text: String

    public init(id: String, kind: JournalEntryKind, text: String) {
        self.id = id
        self.kind = kind
        self.text = text
    }
}

/// Typed side effects applied when the player selects a choice (before advance).
/// No free-form script strings; no dual end-dialogue path (use `endsDialogue` on nodes).
///
/// JSON is a tagged union: `{ "type": "setCaseFlag", "id": "…" }`,
/// `{ "type": "queueJournal", "id": "…", "kind": "chronology", "text": "…" }`.
enum DialogueAction: Equatable, Codable, Sendable {
    case setConversationFlag(String)
    case clearConversationFlag(String)
    case setCaseFlag(String)
    case clearCaseFlag(String)
    case grantKnowledge(String)
    case grantEvidence(String)
    case queueJournal(QueuedJournalFragment)
    /// IE `SetGlobal`.
    case setCounter(String, Int)
    /// IE `IncrementGlobal`. Negative deltas subtract.
    case addToCounter(String, Int)

    private enum CodingKeys: String, CodingKey {
        case type
        case id
        case kind
        case text
        case value
    }

    private enum ActionType: String, Codable {
        case setConversationFlag
        case clearConversationFlag
        case setCaseFlag
        case clearCaseFlag
        case grantKnowledge
        case grantEvidence
        case queueJournal
        case setCounter
        case addToCounter
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ActionType.self, forKey: .type)
        switch type {
        case .setConversationFlag:
            self = .setConversationFlag(try container.decode(String.self, forKey: .id))
        case .clearConversationFlag:
            self = .clearConversationFlag(try container.decode(String.self, forKey: .id))
        case .setCaseFlag:
            self = .setCaseFlag(try container.decode(String.self, forKey: .id))
        case .clearCaseFlag:
            self = .clearCaseFlag(try container.decode(String.self, forKey: .id))
        case .grantKnowledge:
            self = .grantKnowledge(try container.decode(String.self, forKey: .id))
        case .grantEvidence:
            self = .grantEvidence(try container.decode(String.self, forKey: .id))
        case .queueJournal:
            self = .queueJournal(
                QueuedJournalFragment(
                    id: try container.decode(String.self, forKey: .id),
                    kind: try container.decode(JournalEntryKind.self, forKey: .kind),
                    text: try container.decode(String.self, forKey: .text)
                )
            )
        case .setCounter:
            self = .setCounter(
                try container.decode(String.self, forKey: .id),
                try container.decode(Int.self, forKey: .value)
            )
        case .addToCounter:
            self = .addToCounter(
                try container.decode(String.self, forKey: .id),
                try container.decode(Int.self, forKey: .value)
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .setConversationFlag(let id):
            try container.encode(ActionType.setConversationFlag, forKey: .type)
            try container.encode(id, forKey: .id)
        case .clearConversationFlag(let id):
            try container.encode(ActionType.clearConversationFlag, forKey: .type)
            try container.encode(id, forKey: .id)
        case .setCaseFlag(let id):
            try container.encode(ActionType.setCaseFlag, forKey: .type)
            try container.encode(id, forKey: .id)
        case .clearCaseFlag(let id):
            try container.encode(ActionType.clearCaseFlag, forKey: .type)
            try container.encode(id, forKey: .id)
        case .grantKnowledge(let id):
            try container.encode(ActionType.grantKnowledge, forKey: .type)
            try container.encode(id, forKey: .id)
        case .grantEvidence(let id):
            try container.encode(ActionType.grantEvidence, forKey: .type)
            try container.encode(id, forKey: .id)
        case .queueJournal(let fragment):
            try container.encode(ActionType.queueJournal, forKey: .type)
            try container.encode(fragment.id, forKey: .id)
            try container.encode(fragment.kind, forKey: .kind)
            try container.encode(fragment.text, forKey: .text)
        case .setCounter(let id, let value):
            try container.encode(ActionType.setCounter, forKey: .type)
            try container.encode(id, forKey: .id)
            try container.encode(value, forKey: .value)
        case .addToCounter(let id, let value):
            try container.encode(ActionType.addToCounter, forKey: .type)
            try container.encode(id, forKey: .id)
            try container.encode(value, forKey: .value)
        }
    }
}

extension DialogueAction {
    /// The flag / knowledge / evidence id this action writes, or `nil` for actions that
    /// do not produce gateable state. `queueJournal` addresses a casebook fragment, not
    /// a gate, so it is deliberately excluded.
    var writtenStateID: String? {
        switch self {
        case .setConversationFlag(let id),
             .clearConversationFlag(let id),
             .setCaseFlag(let id),
             .clearCaseFlag(let id),
             .grantKnowledge(let id),
             .grantEvidence(let id),
             .setCounter(let id, _),
             .addToCounter(let id, _):
            id
        case .queueJournal:
            nil
        }
    }
}

/// Pure applicator for choice `onSelect` lists. SpriteKit-free.
enum DialogueActionRuntime {
    static func apply(_ actions: [DialogueAction], to context: inout DialogueRuntimeContext) {
        for action in actions {
            apply(action, to: &context)
        }
    }

    static func apply(_ action: DialogueAction, to context: inout DialogueRuntimeContext) {
        switch action {
        case .setConversationFlag(let id):
            context.dialogueState.setConversationFlag(id)
        case .clearConversationFlag(let id):
            context.dialogueState.clearConversationFlag(id)
        case .setCaseFlag(let id):
            context.caseState.setFlag(id)
        case .clearCaseFlag(let id):
            context.caseState.clearFlag(id)
        case .grantKnowledge(let id):
            context.caseState.grantKnowledge(id)
        case .grantEvidence(let id):
            context.caseState.grantEvidence(id)
        case .queueJournal(let fragment):
            context.caseState.queueJournal(fragment)
        case .setCounter(let id, let value):
            context.caseState.setCounter(id, to: value)
        case .addToCounter(let id, let delta):
            context.caseState.addToCounter(id, delta)
        }
    }
}

// MARK: - Phase 1 conditions / triggers

/// Typed condition DSL for choice (and later node) availability.
/// Evaluated against `DialogueRuntimeContext` — no free-form script strings.
///
/// Leaves are tagged unions: `{ "type": "hasFlag", "id": "…" }`. Composites mirror the
/// Infinity Engine's two trigger combinators — `!trigger` and `OR(n)` — as
/// `{ "type": "not", "condition": { … } }` and `{ "type": "any", "conditions": [ … ] }`.
/// A choice's top-level `conditions` array is still ANDed, so every shipped graph reads
/// identically; `.all` exists only so an AND can be nested *inside* an `.any`.
indirect enum DialogueCondition: Equatable, Codable, Sendable {
    case hasFlag(String)
    case hasEvidence(String)
    case hasKnowledge(String)
    /// IE `!trigger`.
    case not(DialogueCondition)
    /// IE `OR(n)`. An empty list is false — "any of nothing" holds for no reason.
    case any([DialogueCondition])
    /// Explicit AND. An empty list is true, matching `allSatisfy` and IE's
    /// "a state with no trigger always fires".
    case all([DialogueCondition])
    /// IE `GlobalGT(id, ·, value - 1)`. Unset counters read as zero.
    case counterAtLeast(String, Int)
    /// IE `GlobalLT(id, ·, value + 1)`.
    case counterAtMost(String, Int)
    /// IE `Global(id, ·, value)`.
    case counterEquals(String, Int)
    /// IE `NumTimesTalkedToGT(atLeast - 1)`. Sugar over `counterAtLeast` on the reserved
    /// `talk.<ownerID>` namespace, so it persists, merges, and reports like any counter
    /// while reading as what it means in authored JSON.
    case timesTalkedTo(ownerID: String, atLeast: Int)

    /// Authoring limit on composite nesting. Deeper than this is a sign the gate wants
    /// to be a flag set by an earlier action, not a bigger expression.
    static let maximumNestingDepth = 8

    /// Backstop against a pathological file recursing the decoder into a stack
    /// overflow before `depth` can be checked. Generous on purpose: it is not the
    /// authoring rule, it is the crash guard. Each composite level costs one or two
    /// coding-path components.
    static let maximumDecodingCodingPathDepth = 64

    private enum CodingKeys: String, CodingKey {
        case type
        case id
        case condition
        case conditions
        case value
    }

    private enum ConditionType: String, Codable {
        case hasFlag
        case hasEvidence
        case hasKnowledge
        case not
        case any
        case all
        case counterAtLeast
        case counterAtMost
        case counterEquals
        case timesTalkedTo
    }

    init(from decoder: Decoder) throws {
        guard decoder.codingPath.count <= Self.maximumDecodingCodingPathDepth else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Dialogue condition nesting is too deep to decode"
                )
            )
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ConditionType.self, forKey: .type)
        switch type {
        case .hasFlag:
            self = .hasFlag(try container.decode(String.self, forKey: .id))
        case .hasEvidence:
            self = .hasEvidence(try container.decode(String.self, forKey: .id))
        case .hasKnowledge:
            self = .hasKnowledge(try container.decode(String.self, forKey: .id))
        case .not:
            self = .not(try container.decode(DialogueCondition.self, forKey: .condition))
        case .any:
            self = .any(try container.decode([DialogueCondition].self, forKey: .conditions))
        case .all:
            self = .all(try container.decode([DialogueCondition].self, forKey: .conditions))
        case .counterAtLeast:
            self = .counterAtLeast(
                try container.decode(String.self, forKey: .id),
                try container.decode(Int.self, forKey: .value)
            )
        case .counterAtMost:
            self = .counterAtMost(
                try container.decode(String.self, forKey: .id),
                try container.decode(Int.self, forKey: .value)
            )
        case .counterEquals:
            self = .counterEquals(
                try container.decode(String.self, forKey: .id),
                try container.decode(Int.self, forKey: .value)
            )
        case .timesTalkedTo:
            self = .timesTalkedTo(
                ownerID: try container.decode(String.self, forKey: .id),
                atLeast: try container.decode(Int.self, forKey: .value)
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .hasFlag(let id):
            try container.encode(ConditionType.hasFlag, forKey: .type)
            try container.encode(id, forKey: .id)
        case .hasEvidence(let id):
            try container.encode(ConditionType.hasEvidence, forKey: .type)
            try container.encode(id, forKey: .id)
        case .hasKnowledge(let id):
            try container.encode(ConditionType.hasKnowledge, forKey: .type)
            try container.encode(id, forKey: .id)
        case .not(let condition):
            try container.encode(ConditionType.not, forKey: .type)
            try container.encode(condition, forKey: .condition)
        case .any(let conditions):
            try container.encode(ConditionType.any, forKey: .type)
            try container.encode(conditions, forKey: .conditions)
        case .all(let conditions):
            try container.encode(ConditionType.all, forKey: .type)
            try container.encode(conditions, forKey: .conditions)
        case .counterAtLeast(let id, let value):
            try container.encode(ConditionType.counterAtLeast, forKey: .type)
            try container.encode(id, forKey: .id)
            try container.encode(value, forKey: .value)
        case .counterAtMost(let id, let value):
            try container.encode(ConditionType.counterAtMost, forKey: .type)
            try container.encode(id, forKey: .id)
            try container.encode(value, forKey: .value)
        case .counterEquals(let id, let value):
            try container.encode(ConditionType.counterEquals, forKey: .type)
            try container.encode(id, forKey: .id)
            try container.encode(value, forKey: .value)
        case .timesTalkedTo(let ownerID, let atLeast):
            try container.encode(ConditionType.timesTalkedTo, forKey: .type)
            try container.encode(ownerID, forKey: .id)
            try container.encode(atLeast, forKey: .value)
        }
    }

    func isSatisfied(by context: DialogueRuntimeContext) -> Bool {
        switch self {
        case .hasFlag(let id):
            context.hasFlag(id)
        case .hasEvidence(let id):
            context.hasEvidence(id)
        case .hasKnowledge(let id):
            context.hasKnowledge(id)
        case .not(let condition):
            !condition.isSatisfied(by: context)
        case .any(let conditions):
            conditions.contains { $0.isSatisfied(by: context) }
        case .all(let conditions):
            conditions.allSatisfy { $0.isSatisfied(by: context) }
        case .counterAtLeast(let id, let value):
            context.counter(id) >= value
        case .counterAtMost(let id, let value):
            context.counter(id) <= value
        case .counterEquals(let id, let value):
            context.counter(id) == value
        case .timesTalkedTo(let ownerID, let atLeast):
            context.counter(CaseState.talkCounterID(ownerID)) >= atLeast
        }
    }

    /// Default player-facing gate reason (GDD §7.5). Flags stay silent unless the
    /// choice authors an explicit `gateDisclosure`.
    ///
    /// A negation never discloses: "[Evidence: Tram Receipt]" on a `.not` would tell the
    /// player about a piece of evidence precisely because they do **not** have it.
    var disclosureLabel: String? {
        switch self {
        case .hasFlag:
            nil
        case .hasEvidence(let id):
            "Evidence: \(Self.humanizeID(id))"
        case .hasKnowledge(let id):
            "Knowledge: \(Self.humanizeID(id))"
        case .not:
            nil
        case .any(let conditions), .all(let conditions):
            conditions.lazy.compactMap(\.disclosureLabel).first
        case .counterAtLeast, .counterAtMost, .counterEquals, .timesTalkedTo:
            // Bookkeeping, like `hasFlag`. "You have talked to her twice" is not a
            // disclosure the player needs in a bracket.
            nil
        }
    }

    /// Nesting depth: a leaf is 1. Checked against `maximumNestingDepth` at load.
    var depth: Int {
        switch self {
        case .hasFlag, .hasEvidence, .hasKnowledge,
             .counterAtLeast, .counterAtMost, .counterEquals, .timesTalkedTo:
            1
        case .not(let condition):
            1 + condition.depth
        case .any(let conditions), .all(let conditions):
            1 + (conditions.map(\.depth).max() ?? 0)
        }
    }

    /// Every flag / evidence / knowledge id this condition reads, composites included.
    ///
    /// Graph integrity uses these to catch the failure mode that actually bites: a
    /// gate keyed on an id no action anywhere can set, which reads as a choice that
    /// simply never appears.
    var referencedIDs: Set<String> {
        switch self {
        case .hasFlag(let id), .hasEvidence(let id), .hasKnowledge(let id),
             .counterAtLeast(let id, _), .counterAtMost(let id, _), .counterEquals(let id, _):
            [id]
        case .timesTalkedTo(let ownerID, _):
            [CaseState.talkCounterID(ownerID)]
        case .not(let condition):
            condition.referencedIDs
        case .any(let conditions), .all(let conditions):
            conditions.reduce(into: Set<String>()) { $0.formUnion($1.referencedIDs) }
        }
    }

    /// `ev.tram-receipt` → `Tram Receipt`; last path segment title-cased.
    private static func humanizeID(_ id: String) -> String {
        let leaf = id.split(separator: ".").last.map(String.init) ?? id
        return leaf
            .split(separator: "-")
            .map { part in
                guard let first = part.first else { return "" }
                return String(first).uppercased() + part.dropFirst().lowercased()
            }
            .joined(separator: " ")
    }
}

struct CaseDialogueChoice: Equatable, Codable, Sendable {
    let text: String
    let destinationID: String
    /// IE **EXTERN**: when set, `destinationID` names a node in *that* graph instead of
    /// this one. Choices only — a DLG transition is the only thing that can jump files,
    /// and `nextNodeID` deliberately stays in-graph for the same reason.
    let destinationGraphID: String?
    /// When set, this is one leg of a Warm / Dry / Sharp triad beat (metadata only).
    let tone: DialogueTone?
    /// Writer approach tag (GDD §7.5). Not shown in the row — same contract as `tone`.
    let intention: DialogueIntention?
    /// All conditions must pass (AND) for the choice to appear. Empty = always available.
    let conditions: [DialogueCondition]
    /// Optional player-facing gate reason override (e.g. `"Evidence: Tram Receipt"`).
    /// Else first non-nil `conditions.disclosureLabel`. Intention names are method
    /// tags and must not be used here as a second morality label.
    let gateDisclosure: String?
    /// Side effects applied on select, before advancing (roadmap Phase 2 runtime order).
    let onSelect: [DialogueAction]

    enum CodingKeys: String, CodingKey {
        case text
        case destinationID
        case destinationGraphID
        case tone
        case intention
        case conditions
        case gateDisclosure
        case onSelect
    }

    init(
        text: String,
        destinationID: String,
        destinationGraphID: String? = nil,
        tone: DialogueTone? = nil,
        intention: DialogueIntention? = nil,
        conditions: [DialogueCondition] = [],
        gateDisclosure: String? = nil,
        onSelect: [DialogueAction] = []
    ) {
        self.text = text
        self.destinationID = destinationID
        self.destinationGraphID = destinationGraphID
        self.tone = tone
        self.intention = intention
        self.conditions = conditions
        self.gateDisclosure = gateDisclosure
        self.onSelect = onSelect
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        text = try container.decode(String.self, forKey: .text)
        destinationID = try container.decode(String.self, forKey: .destinationID)
        destinationGraphID = try container.decodeIfPresent(String.self, forKey: .destinationGraphID)
        tone = try container.decodeIfPresent(DialogueTone.self, forKey: .tone)
        intention = try container.decodeIfPresent(DialogueIntention.self, forKey: .intention)
        conditions = try container.decodeIfPresent([DialogueCondition].self, forKey: .conditions) ?? []
        gateDisclosure = try container.decodeIfPresent(String.self, forKey: .gateDisclosure)
        onSelect = try container.decodeIfPresent([DialogueAction].self, forKey: .onSelect) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(text, forKey: .text)
        try container.encode(destinationID, forKey: .destinationID)
        try container.encodeIfPresent(destinationGraphID, forKey: .destinationGraphID)
        try container.encodeIfPresent(tone, forKey: .tone)
        try container.encodeIfPresent(intention, forKey: .intention)
        if !conditions.isEmpty {
            try container.encode(conditions, forKey: .conditions)
        }
        try container.encodeIfPresent(gateDisclosure, forKey: .gateDisclosure)
        if !onSelect.isEmpty {
            try container.encode(onSelect, forKey: .onSelect)
        }
    }

    /// True when every condition is satisfied (or there are none).
    func isAvailable(in context: DialogueRuntimeContext) -> Bool {
        conditions.allSatisfy { $0.isSatisfied(by: context) }
    }

    /// Bracketed gate reason for the choice row, if any (evidence/knowledge/override).
    /// Intention names are author method and never count as a player-facing gate.
    var resolvedGateDisclosure: String? {
        if let gateDisclosure, !gateDisclosure.isEmpty {
            return Self.playerFacingGateLabel(gateDisclosure)
        }
        return conditions.lazy.compactMap(\.disclosureLabel).first
    }

    /// Writer-facing intention label, if authored. Not a row prefix.
    var resolvedIntentionLabel: String? {
        intention?.displayLabel
    }

    /// Ordered bracket prefixes for the row: evidence/knowledge disclosure only.
    var rowPrefixLabels: [String] {
        guard let gate = resolvedGateDisclosure, !gate.isEmpty else { return [] }
        return [gate]
    }

    /// Choice body for the row with evidence/knowledge prefixes when a special
    /// option needs a reason. Intention tags are not painted (GDD §7.5).
    /// Callers that number rows themselves (e.g. `DialogueTextMetrics.choiceRowHeight`) use this.
    var labeledBodyText: String {
        let prefixes = rowPrefixLabels
        if prefixes.isEmpty {
            return text
        }
        let bracketed = prefixes.map { "[\($0)]" }.joined(separator: "  ")
        return "\(bracketed)  \(text)"
    }

    /// `Open` / `Press` / … are method tags. A leftover `gateDisclosure: "Press"`
    /// must not reappear as a player-facing bracket.
    private static func playerFacingGateLabel(_ raw: String) -> String? {
        let intentionNames = Set(DialogueIntention.allCases.map(\.displayLabel))
        if intentionNames.contains(raw) {
            return nil
        }
        return raw
    }

    /// Fully numbered row text shown in the dialogue panel.
    func displayText(index: Int) -> String {
        "\(index + 1):  \(labeledBodyText)"
    }
}

struct CaseDialogueNode: Equatable, Codable, Sendable {
    let id: String
    let speaker: String
    let text: String
    let portraitName: String?
    let choices: [CaseDialogueChoice]
    let nextNodeID: String?
    let endsDialogue: Bool
    /// First-person interior narration (detective monologue). Presenter renders body text in italics.
    let isInteriorMonologue: Bool
    /// Optional one-shot voice-over resource filename (e.g. `vo_voss_monologue_1.m4a`).
    let voiceAssetName: String?
    /// Presentation cue when leaving this node (Continue / choice). Scene maps cue IDs to handlers.
    /// Not a game-state `DialogueAction` — cinematics stay out of the pure action runtime.
    let onLeaveCue: String?
    /// Optional presentation cue when the node is shown. VO prefers `voiceAssetName`.
    let onShowCue: String?
    /// IE **state trigger**. This node may *open* the conversation only when every
    /// condition passes; empty means always eligible. Ignored once the conversation is
    /// walking — mid-graph a node is entered by its destination link, exactly as in DLG,
    /// where state triggers are consulted only when the dialogue starts.
    let entryWhen: [DialogueCondition]

    enum CodingKeys: String, CodingKey {
        case id
        case speaker
        case text
        case portraitName
        case choices
        case nextNodeID
        case endsDialogue
        case isInteriorMonologue
        case voiceAssetName
        case onLeaveCue
        case onShowCue
        case entryWhen
    }

    init(
        id: String,
        speaker: String,
        text: String,
        portraitName: String? = nil,
        choices: [CaseDialogueChoice] = [],
        nextNodeID: String? = nil,
        endsDialogue: Bool = false,
        isInteriorMonologue: Bool = false,
        voiceAssetName: String? = nil,
        onLeaveCue: String? = nil,
        onShowCue: String? = nil,
        entryWhen: [DialogueCondition] = []
    ) {
        self.id = id
        self.speaker = speaker
        self.text = text
        self.portraitName = portraitName
        self.choices = choices
        self.nextNodeID = nextNodeID
        self.endsDialogue = endsDialogue
        self.isInteriorMonologue = isInteriorMonologue
        self.voiceAssetName = voiceAssetName
        self.onLeaveCue = onLeaveCue
        self.onShowCue = onShowCue
        self.entryWhen = entryWhen
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        speaker = try container.decode(String.self, forKey: .speaker)
        text = try container.decode(String.self, forKey: .text)
        portraitName = try container.decodeIfPresent(String.self, forKey: .portraitName)
        choices = try container.decodeIfPresent([CaseDialogueChoice].self, forKey: .choices) ?? []
        nextNodeID = try container.decodeIfPresent(String.self, forKey: .nextNodeID)
        endsDialogue = try container.decodeIfPresent(Bool.self, forKey: .endsDialogue) ?? false
        isInteriorMonologue = try container.decodeIfPresent(Bool.self, forKey: .isInteriorMonologue) ?? false
        voiceAssetName = try container.decodeIfPresent(String.self, forKey: .voiceAssetName)
        onLeaveCue = try container.decodeIfPresent(String.self, forKey: .onLeaveCue)
        onShowCue = try container.decodeIfPresent(String.self, forKey: .onShowCue)
        entryWhen = try container.decodeIfPresent([DialogueCondition].self, forKey: .entryWhen) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(speaker, forKey: .speaker)
        try container.encode(text, forKey: .text)
        try container.encodeIfPresent(portraitName, forKey: .portraitName)
        if !choices.isEmpty {
            try container.encode(choices, forKey: .choices)
        }
        try container.encodeIfPresent(nextNodeID, forKey: .nextNodeID)
        if endsDialogue {
            try container.encode(endsDialogue, forKey: .endsDialogue)
        }
        if isInteriorMonologue {
            try container.encode(isInteriorMonologue, forKey: .isInteriorMonologue)
        }
        try container.encodeIfPresent(voiceAssetName, forKey: .voiceAssetName)
        try container.encodeIfPresent(onLeaveCue, forKey: .onLeaveCue)
        try container.encodeIfPresent(onShowCue, forKey: .onShowCue)
        if !entryWhen.isEmpty {
            try container.encode(entryWhen, forKey: .entryWhen)
        }
    }
}

/// Pure graph helpers used by tests and any tool that validates authored dialogue.
enum CaseDialogueGraph {
    struct IntegrityReport: Equatable, Sendable {
        var missingDestinationIDs: [String]
        var orphanNodeIDs: [String]
        var reachableNodeIDs: Set<String>
        var reachesEnding: Bool
        var triadChoiceBeats: Int
        var totalBodyCharacters: Int
        /// Choices that carry at least one condition (diagnostic only).
        var gatedChoiceCount: Int
        /// Choices that author at least one `onSelect` action (diagnostic).
        var actionChoiceCount: Int
        /// Node ids authored more than once. A duplicate silently shadows the earlier
        /// node in every lookup, so a graph carrying one is not sound even if every
        /// destination happens to resolve.
        var duplicateNodeIDs: [String]
        /// Every flag / evidence / knowledge id read by a condition in this graph.
        var conditionLeafIDs: Set<String>
        /// Every such id written by an `onSelect` action in this graph.
        var actionWrittenStateIDs: Set<String>
        /// Gate ids this graph reads but never writes — sorted, diagnostic only.
        ///
        /// Not part of `isSound`: a gate legitimately reads state produced elsewhere
        /// (a hotspot granting evidence, a flag from an earlier conversation). It is
        /// still the cheapest way to catch a typo'd id, which presents as a choice that
        /// simply never appears.
        var externallySuppliedConditionIDs: [String]
        /// Deepest composite condition, 1 for a plain leaf, 0 when nothing is gated.
        var maximumConditionDepth: Int
        /// Entry candidates naming a node that does not exist.
        var missingEntryNodeIDs: [String]
        /// False when the start node carries an `entryWhen`. The entry fallback returns
        /// `startNodeID` unconditionally, so a gate there never runs — the entry-side
        /// mirror of "gated-only endings need an ungated path".
        var startNodeIsUnconditional: Bool

        /// Everything `isSound` checks except "an ending is reachable from here".
        ///
        /// A graph whose only exit is a cross-graph jump cannot satisfy `reachesEnding` on
        /// its own and is not broken for it — that check belongs to
        /// `CaseDialogueGraph.report(catalog:)`, which can follow the link.
        var isStructurallySound: Bool {
            missingDestinationIDs.isEmpty
                && duplicateNodeIDs.isEmpty
                && missingEntryNodeIDs.isEmpty
                && startNodeIsUnconditional
        }

        var isSound: Bool {
            isStructurallySound && reachesEnding
        }
    }

    /// Choices available under the given context (AND conditions). Order preserved.
    static func visibleChoices(
        _ choices: [CaseDialogueChoice],
        in context: DialogueRuntimeContext
    ) -> [CaseDialogueChoice] {
        choices.filter { $0.isAvailable(in: context) }
    }

    /// True when a node has no player path forward given current visibility.
    /// Authoring risk if conditions leave only a dead end (debug soft-fail).
    static func isSoftStuck(
        node: CaseDialogueNode,
        visibleChoices: [CaseDialogueChoice]
    ) -> Bool {
        visibleChoices.isEmpty
            && node.nextNodeID == nil
            && !node.endsDialogue
    }

    static func report(
        nodes: [CaseDialogueNode],
        startID: String,
        entryNodeIDs: [String] = []
    ) -> IntegrityReport {
        // Loop rather than `Dictionary(uniqueKeysWithValues:)`: the latter traps on a
        // duplicate id, which turned an authoring typo into a crash inside the very
        // helper meant to *report* authoring problems.
        var byID: [String: CaseDialogueNode] = [:]
        byID.reserveCapacity(nodes.count)
        var duplicates: [String] = []
        for node in nodes {
            if byID.updateValue(node, forKey: node.id) != nil, !duplicates.contains(node.id) {
                duplicates.append(node.id)
            }
        }
        var missing: [String] = []
        var reachable: Set<String> = []
        var triadBeats = 0
        var bodyChars = 0
        var gatedChoiceCount = 0
        var actionChoiceCount = 0
        var conditionLeafIDs: Set<String> = []
        var actionWrittenStateIDs: Set<String> = []
        var maximumConditionDepth = 0

        for node in nodes {
            bodyChars += node.text.count
            for condition in node.entryWhen {
                conditionLeafIDs.formUnion(condition.referencedIDs)
                maximumConditionDepth = max(maximumConditionDepth, condition.depth)
            }
            let tones = Set(node.choices.compactMap(\.tone))
            // Triad = all three tones present among *ungated or any* tone-tagged legs.
            let toneTagged = node.choices.filter { $0.tone != nil }
            if tones == Set(DialogueTone.allCases) && toneTagged.count >= 3 {
                triadBeats += 1
            }
            for choice in node.choices {
                if !choice.conditions.isEmpty {
                    gatedChoiceCount += 1
                }
                if !choice.onSelect.isEmpty {
                    actionChoiceCount += 1
                }
                for condition in choice.conditions {
                    conditionLeafIDs.formUnion(condition.referencedIDs)
                    maximumConditionDepth = max(maximumConditionDepth, condition.depth)
                }
                actionWrittenStateIDs.formUnion(choice.onSelect.compactMap(\.writtenStateID))
                // A cross-graph destination is resolved by the catalog, not here.
                // `CaseDialogueGraph.report(catalog:)` checks those.
                if choice.destinationGraphID == nil, byID[choice.destinationID] == nil {
                    missing.append("\(node.id)->\(choice.destinationID)")
                }
            }
            if let next = node.nextNodeID, byID[next] == nil {
                missing.append("\(node.id)->next:\(next)")
            }
        }

        // Reachability ignores conditions: gates may unlock mid-conversation.
        // Gated-only endings still need an ungated path for isSound.
        //
        // Seed from *every* entry candidate, not just `startID` — an alternate opening
        // is reachable by definition, and seeding from the start node alone would report
        // a whole re-talk branch as orphaned.
        var queue: [String] = []
        for seed in entryNodeIDs + [startID] where byID[seed] != nil {
            if reachable.insert(seed).inserted {
                queue.append(seed)
            }
        }
        var head = 0
        while head < queue.count {
            let id = queue[head]
            head += 1
            guard let node = byID[id] else { continue }
            var outs: [String] = node.choices
                .filter { $0.destinationGraphID == nil }
                .map(\.destinationID)
            if let next = node.nextNodeID {
                outs.append(next)
            }
            for dest in outs where !reachable.contains(dest) {
                if byID[dest] != nil {
                    reachable.insert(dest)
                    queue.append(dest)
                }
            }
        }

        let orphans = nodes.map(\.id).filter { !reachable.contains($0) }
        let reachesEnding = nodes.contains { reachable.contains($0.id) && $0.endsDialogue }

        return IntegrityReport(
            missingDestinationIDs: missing.sorted(),
            orphanNodeIDs: orphans.sorted(),
            reachableNodeIDs: reachable,
            reachesEnding: reachesEnding,
            triadChoiceBeats: triadBeats,
            totalBodyCharacters: bodyChars,
            gatedChoiceCount: gatedChoiceCount,
            actionChoiceCount: actionChoiceCount,
            duplicateNodeIDs: duplicates,
            conditionLeafIDs: conditionLeafIDs,
            actionWrittenStateIDs: actionWrittenStateIDs,
            externallySuppliedConditionIDs: conditionLeafIDs
                .subtracting(actionWrittenStateIDs)
                .sorted(),
            maximumConditionDepth: maximumConditionDepth,
            missingEntryNodeIDs: entryNodeIDs.filter { byID[$0] == nil },
            startNodeIsUnconditional: byID[startID]?.entryWhen.isEmpty ?? true
        )
    }
}
