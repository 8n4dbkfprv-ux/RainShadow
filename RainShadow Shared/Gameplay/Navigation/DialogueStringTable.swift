import Foundation

// MARK: - String table (IE TLK analogue)

/// On-disk dialogue string table (locale → key → prose).
///
/// Graphs may reference keys (`textKey` / `speakerKey`) instead of inline strings.
/// `DialogueGraphLoader` resolves keys at load time into runtime `DialogueGraph`
/// values so the walker/UI stay string-backed.
struct DialogueStringTableDocument: Equatable, Codable, Sendable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    /// BCP-47-ish locale tag (e.g. `"en"`).
    var locale: String
    var strings: [String: String]

    init(
        schemaVersion: Int = DialogueStringTableDocument.currentSchemaVersion,
        locale: String = "en",
        strings: [String: String]
    ) {
        self.schemaVersion = schemaVersion
        self.locale = locale
        self.strings = strings
    }
}

/// Resolved lookup table for dialogue authoring keys.
struct DialogueStringTable: Equatable, Sendable {
    /// Default English table resource base name (`strings.en.json`).
    static let defaultResourceName = "strings.en"
    static let defaultLocale = "en"

    var locale: String
    private var strings: [String: String]

    init(locale: String = defaultLocale, strings: [String: String] = [:]) {
        self.locale = locale
        self.strings = strings
    }

    init(document: DialogueStringTableDocument) {
        self.locale = document.locale
        self.strings = document.strings
    }

    var count: Int { strings.count }

    func contains(_ key: String) -> Bool {
        strings[key] != nil
    }

    func string(for key: String) throws -> String {
        guard let value = strings[key] else {
            throw DialogueStringTableError.missingKey(key)
        }
        return value
    }

    /// Prefer key when present; else inline; else error.
    func resolve(inline: String?, key: String?, field: String) throws -> String {
        if let key, !key.isEmpty {
            return try string(for: key)
        }
        if let inline {
            return inline
        }
        throw DialogueStringTableError.missingTextAndKey(field: field)
    }

    // MARK: - Load

    private static let cacheLock = NSLock()
    nonisolated(unsafe) private static var tableCache: [String: DialogueStringTable] = [:]

    static func load(
        resourceName: String = defaultResourceName,
        bundle: Bundle? = nil
    ) throws -> DialogueStringTable {
        cacheLock.lock()
        if let hit = tableCache[resourceName] {
            cacheLock.unlock()
            return hit
        }
        cacheLock.unlock()

        let data = try DialogueGraphLoader.resourceData(
            resourceName: resourceName,
            bundle: bundle,
            lookupID: resourceName
        )
        let table = try decode(data)
        cacheLock.lock()
        tableCache[resourceName] = table
        cacheLock.unlock()
        return table
    }

    static func decode(_ data: Data) throws -> DialogueStringTable {
        let decoder = JSONDecoder()
        let document = try decoder.decode(DialogueStringTableDocument.self, from: data)
        guard document.schemaVersion == DialogueStringTableDocument.currentSchemaVersion else {
            throw DialogueStringTableError.unsupportedSchemaVersion(
                found: document.schemaVersion,
                supported: DialogueStringTableDocument.currentSchemaVersion
            )
        }
        return DialogueStringTable(document: document)
    }

    static func encode(
        _ table: DialogueStringTable,
        prettyPrinted: Bool = true
    ) throws -> Data {
        let document = DialogueStringTableDocument(
            locale: table.locale,
            strings: table.strings
        )
        let encoder = JSONEncoder()
        if prettyPrinted {
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        }
        return try encoder.encode(document)
    }

    /// Empty table — allows pure-inline authored graphs without a resource file.
    static var empty: DialogueStringTable { DialogueStringTable() }
}

enum DialogueStringTableError: Error, Equatable, CustomStringConvertible {
    case unsupportedSchemaVersion(found: Int, supported: Int)
    case missingKey(String)
    case missingTextAndKey(field: String)

    var description: String {
        switch self {
        case .unsupportedSchemaVersion(let found, let supported):
            "Dialogue string table schema version \(found) is not supported (expected \(supported))"
        case .missingKey(let key):
            "Dialogue string table is missing key '\(key)'"
        case .missingTextAndKey(let field):
            "Dialogue authoring field '\(field)' needs inline text or a textKey/speakerKey"
        }
    }
}

// MARK: - Authored (pre-resolve) graph models

/// Versioned graph as authored on disk: prose may be inline or string-table keys.
struct AuthoredDialogueDocument: Equatable, Codable, Sendable {
    var schemaVersion: Int
    var id: String
    var startNodeID: String
    var nodes: [AuthoredDialogueNode]
    /// Optional string-table resource override (default `strings.en`).
    var stringTable: String?

    init(
        schemaVersion: Int = DialogueDocument.currentSchemaVersion,
        id: String,
        startNodeID: String,
        nodes: [AuthoredDialogueNode],
        stringTable: String? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.startNodeID = startNodeID
        self.nodes = nodes
        self.stringTable = stringTable
    }
}

struct AuthoredDialogueNode: Equatable, Codable, Sendable {
    var id: String
    var speaker: String?
    var speakerKey: String?
    var text: String?
    var textKey: String?
    var portraitName: String?
    var choices: [AuthoredDialogueChoice]
    var nextNodeID: String?
    var endsDialogue: Bool
    var isInteriorMonologue: Bool
    var voiceAssetName: String?
    var onLeaveCue: String?
    var onShowCue: String?

    enum CodingKeys: String, CodingKey {
        case id
        case speaker
        case speakerKey
        case text
        case textKey
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
        speaker: String? = nil,
        speakerKey: String? = nil,
        text: String? = nil,
        textKey: String? = nil,
        portraitName: String? = nil,
        choices: [AuthoredDialogueChoice] = [],
        nextNodeID: String? = nil,
        endsDialogue: Bool = false,
        isInteriorMonologue: Bool = false,
        voiceAssetName: String? = nil,
        onLeaveCue: String? = nil,
        onShowCue: String? = nil
    ) {
        self.id = id
        self.speaker = speaker
        self.speakerKey = speakerKey
        self.text = text
        self.textKey = textKey
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
        speaker = try container.decodeIfPresent(String.self, forKey: .speaker)
        speakerKey = try container.decodeIfPresent(String.self, forKey: .speakerKey)
        text = try container.decodeIfPresent(String.self, forKey: .text)
        textKey = try container.decodeIfPresent(String.self, forKey: .textKey)
        portraitName = try container.decodeIfPresent(String.self, forKey: .portraitName)
        choices = try container.decodeIfPresent([AuthoredDialogueChoice].self, forKey: .choices) ?? []
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
        try container.encodeIfPresent(speaker, forKey: .speaker)
        try container.encodeIfPresent(speakerKey, forKey: .speakerKey)
        try container.encodeIfPresent(text, forKey: .text)
        try container.encodeIfPresent(textKey, forKey: .textKey)
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

struct AuthoredDialogueChoice: Equatable, Codable, Sendable {
    var text: String?
    var textKey: String?
    var destinationID: String
    var tone: DialogueTone?
    var intention: DialogueIntention?
    var conditions: [DialogueCondition]
    var gateDisclosure: String?
    var onSelect: [AuthoredDialogueAction]

    enum CodingKeys: String, CodingKey {
        case text
        case textKey
        case destinationID
        case tone
        case intention
        case conditions
        case gateDisclosure
        case onSelect
    }

    init(
        text: String? = nil,
        textKey: String? = nil,
        destinationID: String,
        tone: DialogueTone? = nil,
        intention: DialogueIntention? = nil,
        conditions: [DialogueCondition] = [],
        gateDisclosure: String? = nil,
        onSelect: [AuthoredDialogueAction] = []
    ) {
        self.text = text
        self.textKey = textKey
        self.destinationID = destinationID
        self.tone = tone
        self.intention = intention
        self.conditions = conditions
        self.gateDisclosure = gateDisclosure
        self.onSelect = onSelect
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        text = try container.decodeIfPresent(String.self, forKey: .text)
        textKey = try container.decodeIfPresent(String.self, forKey: .textKey)
        destinationID = try container.decode(String.self, forKey: .destinationID)
        tone = try container.decodeIfPresent(DialogueTone.self, forKey: .tone)
        intention = try container.decodeIfPresent(DialogueIntention.self, forKey: .intention)
        conditions = try container.decodeIfPresent([DialogueCondition].self, forKey: .conditions) ?? []
        gateDisclosure = try container.decodeIfPresent(String.self, forKey: .gateDisclosure)
        onSelect = try container.decodeIfPresent([AuthoredDialogueAction].self, forKey: .onSelect) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(text, forKey: .text)
        try container.encodeIfPresent(textKey, forKey: .textKey)
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
}

/// Authored side effects; `queueJournal` may use `textKey` instead of inline `text`.
enum AuthoredDialogueAction: Equatable, Codable, Sendable {
    case setConversationFlag(String)
    case clearConversationFlag(String)
    case setCaseFlag(String)
    case clearCaseFlag(String)
    case grantKnowledge(String)
    case grantEvidence(String)
    case queueJournal(id: String, kind: String, text: String?, textKey: String?)

    private enum CodingKeys: String, CodingKey {
        case type
        case id
        case kind
        case text
        case textKey
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
                id: try container.decode(String.self, forKey: .id),
                kind: try container.decode(String.self, forKey: .kind),
                text: try container.decodeIfPresent(String.self, forKey: .text),
                textKey: try container.decodeIfPresent(String.self, forKey: .textKey)
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
        case .queueJournal(let id, let kind, let text, let textKey):
            try container.encode(ActionType.queueJournal, forKey: .type)
            try container.encode(id, forKey: .id)
            try container.encode(kind, forKey: .kind)
            try container.encodeIfPresent(text, forKey: .text)
            try container.encodeIfPresent(textKey, forKey: .textKey)
        }
    }
}

// MARK: - Resolution

extension DialogueStringTable {
    func resolve(_ document: AuthoredDialogueDocument) throws -> DialogueGraph {
        let nodes = try document.nodes.map { try resolve($0) }
        let graph = DialogueGraph(
            id: document.id,
            startNodeID: document.startNodeID,
            nodes: nodes
        )
        if graph.nodes.isEmpty {
            throw DialogueGraphLoaderError.emptyGraph(id: graph.id)
        }
        if graph.node(id: graph.startNodeID) == nil {
            throw DialogueGraphLoaderError.missingStartNode(
                graphID: graph.id,
                startNodeID: graph.startNodeID
            )
        }
        return graph
    }

    func resolve(_ node: AuthoredDialogueNode) throws -> CaseDialogueNode {
        let speaker = try resolve(
            inline: node.speaker,
            key: node.speakerKey,
            field: "node[\(node.id)].speaker"
        )
        let text = try resolve(
            inline: node.text,
            key: node.textKey,
            field: "node[\(node.id)].text"
        )
        let choices = try node.choices.enumerated().map { index, choice in
            try resolve(choice, nodeID: node.id, choiceIndex: index)
        }
        return CaseDialogueNode(
            id: node.id,
            speaker: speaker,
            text: text,
            portraitName: node.portraitName,
            choices: choices,
            nextNodeID: node.nextNodeID,
            endsDialogue: node.endsDialogue,
            isInteriorMonologue: node.isInteriorMonologue,
            voiceAssetName: node.voiceAssetName,
            onLeaveCue: node.onLeaveCue,
            onShowCue: node.onShowCue
        )
    }

    func resolve(
        _ choice: AuthoredDialogueChoice,
        nodeID: String,
        choiceIndex: Int
    ) throws -> CaseDialogueChoice {
        let text = try resolve(
            inline: choice.text,
            key: choice.textKey,
            field: "node[\(nodeID)].choice[\(choiceIndex)].text"
        )
        let actions = try choice.onSelect.map { try resolve($0) }
        return CaseDialogueChoice(
            text: text,
            destinationID: choice.destinationID,
            tone: choice.tone,
            intention: choice.intention,
            conditions: choice.conditions,
            gateDisclosure: choice.gateDisclosure,
            onSelect: actions
        )
    }

    func resolve(_ action: AuthoredDialogueAction) throws -> DialogueAction {
        switch action {
        case .setConversationFlag(let id):
            return .setConversationFlag(id)
        case .clearConversationFlag(let id):
            return .clearConversationFlag(id)
        case .setCaseFlag(let id):
            return .setCaseFlag(id)
        case .clearCaseFlag(let id):
            return .clearCaseFlag(id)
        case .grantKnowledge(let id):
            return .grantKnowledge(id)
        case .grantEvidence(let id):
            return .grantEvidence(id)
        case .queueJournal(let id, let kind, let text, let textKey):
            let resolved = try resolve(
                inline: text,
                key: textKey,
                field: "queueJournal[\(id)].text"
            )
            return .queueJournal(QueuedJournalFragment(id: id, kind: kind, text: resolved))
        }
    }
}

// MARK: - Authored catalog

struct AuthoredDialogueCatalogDocument: Equatable, Codable, Sendable {
    var schemaVersion: Int
    var graphs: [AuthoredDialogueCatalogGraph]
    var stringTable: String?

    init(
        schemaVersion: Int = DialogueCatalogDocument.currentSchemaVersion,
        graphs: [AuthoredDialogueCatalogGraph],
        stringTable: String? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.graphs = graphs
        self.stringTable = stringTable
    }
}

struct AuthoredDialogueCatalogGraph: Equatable, Codable, Sendable {
    var id: String
    var startNodeID: String
    var nodes: [AuthoredDialogueNode]
}
