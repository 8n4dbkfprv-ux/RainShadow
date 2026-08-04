import Foundation

/// Authoring tone triad for major response beats.
/// Not shown in UI — players read the line; tone is for writers, branching, and tests.
enum DialogueTone: String, Equatable, CaseIterable, Sendable {
    case goodHeroic = "Good/Heroic"
    case neutralPragmatic = "Neutral/Pragmatic"
    case cynicalSarcasm = "Cynical/Sarcasm"
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
enum DialogueAction: Equatable, Sendable {
    case setConversationFlag(String)
    case clearConversationFlag(String)
    case setCaseFlag(String)
    case clearCaseFlag(String)
    case grantKnowledge(String)
    case grantEvidence(String)
    case queueJournal(QueuedJournalFragment)
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
enum DialogueCondition: Equatable, Sendable {
    case hasFlag(String)
    case hasEvidence(String)
    case hasKnowledge(String)

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

struct CaseDialogueChoice: Equatable, Sendable {
    let text: String
    let destinationID: String
    /// When set, this is one leg of a Good / Neutral / Cynical triad beat (metadata only).
    let tone: DialogueTone?
    /// All conditions must pass (AND) for the choice to appear. Empty = always available.
    let conditions: [DialogueCondition]
    /// Optional player-facing gate reason override (e.g. `"Press"`). Else first
    /// non-nil `conditions.disclosureLabel`.
    let gateDisclosure: String?
    /// Side effects applied on select, before advancing (roadmap Phase 2 runtime order).
    let onSelect: [DialogueAction]

    init(
        text: String,
        destinationID: String,
        tone: DialogueTone? = nil,
        conditions: [DialogueCondition] = [],
        gateDisclosure: String? = nil,
        onSelect: [DialogueAction] = []
    ) {
        self.text = text
        self.destinationID = destinationID
        self.tone = tone
        self.conditions = conditions
        self.gateDisclosure = gateDisclosure
        self.onSelect = onSelect
    }

    /// True when every condition is satisfied (or there are none).
    func isAvailable(in context: DialogueRuntimeContext) -> Bool {
        conditions.allSatisfy { $0.isSatisfied(by: context) }
    }

    /// Bracketed gate reason for the choice row, if any.
    var resolvedGateDisclosure: String? {
        if let gateDisclosure, !gateDisclosure.isEmpty {
            return gateDisclosure
        }
        return conditions.lazy.compactMap(\.disclosureLabel).first
    }

    /// Choice body for the row, optionally with GDD-style `[Evidence: …]` prefix.
    /// Callers that number rows themselves (e.g. `DialogueTextMetrics.choiceRowHeight`) use this.
    var labeledBodyText: String {
        if let disclosure = resolvedGateDisclosure {
            return "[\(disclosure)]  \(text)"
        }
        return text
    }

    /// Fully numbered row text shown in the dialogue panel.
    func displayText(index: Int) -> String {
        "\(index + 1):  \(labeledBodyText)"
    }
}

struct CaseDialogueNode: Equatable, Sendable {
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

    init(
        id: String,
        speaker: String,
        text: String,
        portraitName: String? = nil,
        choices: [CaseDialogueChoice] = [],
        nextNodeID: String? = nil,
        endsDialogue: Bool = false,
        isInteriorMonologue: Bool = false,
        voiceAssetName: String? = nil
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
