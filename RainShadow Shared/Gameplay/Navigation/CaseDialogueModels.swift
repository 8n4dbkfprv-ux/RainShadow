import Foundation

/// Authoring tone triad for major response beats.
/// Not shown in UI — players read the line; tone is for writers, branching, and tests.
///
/// JSON uses case names (`goodHeroic`, …). Display labels stay on `displayLabel`.
enum DialogueTone: String, Equatable, CaseIterable, Codable, Sendable {
    case goodHeroic
    case neutralPragmatic
    case cynicalSarcasm

    /// Writer-facing label (not player UI).
    var displayLabel: String {
        switch self {
        case .goodHeroic: "Good/Heroic"
        case .neutralPragmatic: "Neutral/Pragmatic"
        case .cynicalSarcasm: "Cynical/Sarcasm"
        }
    }
}

/// Player-facing dialogue approach tags (GDD §7.5). Shown as `[Open]`-style prefixes.
/// Complements writer-only `DialogueTone`; does not encode morality meters.
enum DialogueIntention: String, Equatable, CaseIterable, Codable, Sendable {
    case open
    case press
    case feign
    case trade
    case observe
    case leave

    /// Bracket label in the choice row (GDD §7.5 taxonomy).
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

/// Dialogue-earned journal payload. Projected into the casebook in Phase 3.
public struct QueuedJournalFragment: Codable, Equatable, Sendable {
    public var id: String
    /// e.g. `"chronology"` or `"lead"`.
    public var kind: String
    public var text: String

    public init(id: String, kind: String, text: String) {
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

    private enum CodingKeys: String, CodingKey {
        case type
        case id
        case kind
        case text
    }

    private enum ActionType: String, Codable {
        case setConversationFlag
        case clearConversationFlag
        case setCaseFlag
        case clearCaseFlag
        case grantKnowledge
        case grantEvidence
        case queueJournal
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
                    kind: try container.decode(String.self, forKey: .kind),
                    text: try container.decode(String.self, forKey: .text)
                )
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
        }
    }
}

// MARK: - Phase 1 conditions / triggers

/// Typed condition DSL for choice (and later node) availability.
/// Evaluated against `DialogueRuntimeContext` — no free-form script strings.
///
/// JSON is a tagged union: `{ "type": "hasFlag", "id": "…" }`.
enum DialogueCondition: Equatable, Codable, Sendable {
    case hasFlag(String)
    case hasEvidence(String)
    case hasKnowledge(String)

    private enum CodingKeys: String, CodingKey {
        case type
        case id
    }

    private enum ConditionType: String, Codable {
        case hasFlag
        case hasEvidence
        case hasKnowledge
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ConditionType.self, forKey: .type)
        let id = try container.decode(String.self, forKey: .id)
        switch type {
        case .hasFlag:
            self = .hasFlag(id)
        case .hasEvidence:
            self = .hasEvidence(id)
        case .hasKnowledge:
            self = .hasKnowledge(id)
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
        }
    }

    /// Default player-facing gate reason (GDD §7.5). Flags stay silent unless the
    /// choice authors an explicit `gateDisclosure`.
    var disclosureLabel: String? {
        switch self {
        case .hasFlag:
            nil
        case .hasEvidence(let id):
            "Evidence: \(Self.humanizeID(id))"
        case .hasKnowledge(let id):
            "Knowledge: \(Self.humanizeID(id))"
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
    /// When set, this is one leg of a Good / Neutral / Cynical triad beat (metadata only).
    let tone: DialogueTone?
    /// Player-facing approach tag (GDD §7.5). Shown as `[Open]` / `[Press]` / … in the row.
    let intention: DialogueIntention?
    /// All conditions must pass (AND) for the choice to appear. Empty = always available.
    let conditions: [DialogueCondition]
    /// Optional player-facing gate reason override (e.g. `"Press"`). Else first
    /// non-nil `conditions.disclosureLabel`. Prefer `intention` for approach tags;
    /// keep this for evidence/knowledge disclosure overrides.
    let gateDisclosure: String?
    /// Side effects applied on select, before advancing (roadmap Phase 2 runtime order).
    let onSelect: [DialogueAction]

    enum CodingKeys: String, CodingKey {
        case text
        case destinationID
        case tone
        case intention
        case conditions
        case gateDisclosure
        case onSelect
    }

    init(
        text: String,
        destinationID: String,
        tone: DialogueTone? = nil,
        intention: DialogueIntention? = nil,
        conditions: [DialogueCondition] = [],
        gateDisclosure: String? = nil,
        onSelect: [DialogueAction] = []
    ) {
        self.text = text
        self.destinationID = destinationID
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
    /// Does not include intention tags — see `resolvedIntentionLabel`.
    var resolvedGateDisclosure: String? {
        if let gateDisclosure, !gateDisclosure.isEmpty {
            return gateDisclosure
        }
        return conditions.lazy.compactMap(\.disclosureLabel).first
    }

    /// Player-facing intention bracket label, if authored.
    var resolvedIntentionLabel: String? {
        intention?.displayLabel
    }

    /// Ordered bracket prefixes for the row: intention first, then gate disclosure.
    /// Drops a gate label that exactly matches the intention label (e.g. legacy `gateDisclosure: "Press"`).
    var rowPrefixLabels: [String] {
        var labels: [String] = []
        if let intentionLabel = resolvedIntentionLabel {
            labels.append(intentionLabel)
        }
        if let gate = resolvedGateDisclosure, !gate.isEmpty {
            if gate != resolvedIntentionLabel {
                labels.append(gate)
            }
        }
        return labels
    }

    /// Choice body for the row with GDD-style `[Open]` / `[Evidence: …]` prefixes.
    /// Callers that number rows themselves (e.g. `DialogueTextMetrics.choiceRowHeight`) use this.
    var labeledBodyText: String {
        let prefixes = rowPrefixLabels
        if prefixes.isEmpty {
            return text
        }
        let bracketed = prefixes.map { "[\($0)]" }.joined(separator: "  ")
        return "\(bracketed)  \(text)"
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
        onShowCue: String? = nil
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

        var isSound: Bool {
            missingDestinationIDs.isEmpty && reachesEnding
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

    static func report(nodes: [CaseDialogueNode], startID: String) -> IntegrityReport {
        let byID = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })
        var missing: [String] = []
        var reachable: Set<String> = []
        var triadBeats = 0
        var bodyChars = 0
        var gatedChoiceCount = 0
        var actionChoiceCount = 0

        for node in nodes {
            bodyChars += node.text.count
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
                if byID[choice.destinationID] == nil {
                    missing.append("\(node.id)->\(choice.destinationID)")
                }
            }
            if let next = node.nextNodeID, byID[next] == nil {
                missing.append("\(node.id)->next:\(next)")
            }
        }

        // Reachability ignores conditions: gates may unlock mid-conversation.
        // Gated-only endings still need an ungated path for isSound.
        var queue = [startID]
        if byID[startID] != nil {
            reachable.insert(startID)
        }
        var head = 0
        while head < queue.count {
            let id = queue[head]
            head += 1
            guard let node = byID[id] else { continue }
            var outs: [String] = node.choices.map(\.destinationID)
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
            actionChoiceCount: actionChoiceCount
        )
    }
}
