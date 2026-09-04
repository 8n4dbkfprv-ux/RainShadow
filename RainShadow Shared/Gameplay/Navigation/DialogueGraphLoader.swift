import Foundation

// MARK: - Versioned dialogue document (external authoring)

/// On-disk / resource representation of a conversation graph.
/// Runtime engine consumes `DialogueGraph`; this wrapper carries schema versioning.
struct DialogueDocument: Equatable, Codable, Sendable {
    /// Supported loader schema. Bump only with a migration path.
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var id: String
    var startNodeID: String
    /// Ordered entry candidates (IE `FindFirstState`). Absent means `[startNodeID]`.
    var entryNodeIDs: [String]?
    var nodes: [CaseDialogueNode]

    init(
        schemaVersion: Int = DialogueDocument.currentSchemaVersion,
        id: String,
        startNodeID: String,
        entryNodeIDs: [String]? = nil,
        nodes: [CaseDialogueNode]
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.startNodeID = startNodeID
        self.entryNodeIDs = entryNodeIDs
        self.nodes = nodes
    }

    init(graph: DialogueGraph, schemaVersion: Int = DialogueDocument.currentSchemaVersion) {
        self.schemaVersion = schemaVersion
        self.id = graph.id
        self.startNodeID = graph.startNodeID
        self.entryNodeIDs = graph.entryNodeIDs.isEmpty ? nil : graph.entryNodeIDs
        self.nodes = graph.nodes
    }

    var graph: DialogueGraph {
        DialogueGraph(
            id: id,
            startNodeID: startNodeID,
            entryNodeIDs: entryNodeIDs ?? [],
            nodes: nodes
        )
    }
}

// MARK: - Loader errors

/// Multi-graph package (e.g. office hotspot inspect lines) under one resource file.
/// Resolved multi-graph package (runtime). Prefer loading via `DialogueGraphLoader.loadCatalog`.
struct DialogueCatalogDocument: Equatable, Codable, Sendable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    /// Graph entries share the catalog schema version (no nested schemaVersion per graph).
    var graphs: [DialogueCatalogGraph]

    init(
        schemaVersion: Int = DialogueCatalogDocument.currentSchemaVersion,
        graphs: [DialogueCatalogGraph]
    ) {
        self.schemaVersion = schemaVersion
        self.graphs = graphs
    }

    /// Runtime graphs in authored order.
    ///
    /// A `graphsByID()` twin used to sit here built on `Dictionary(uniqueKeysWithValues:)`,
    /// which trapped on a duplicate catalog id. Nothing called either one — the shipped
    /// path is `DialogueGraphLoader.decodeCatalog`, which now rejects duplicates.
    var runtimeGraphs: [DialogueGraph] {
        graphs.map(\.graph)
    }
}

struct DialogueCatalogGraph: Equatable, Codable, Sendable {
    var id: String
    var startNodeID: String
    /// Ordered entry candidates (IE `FindFirstState`). Absent means `[startNodeID]`.
    var entryNodeIDs: [String]?
    var nodes: [CaseDialogueNode]

    init(
        id: String,
        startNodeID: String,
        entryNodeIDs: [String]? = nil,
        nodes: [CaseDialogueNode]
    ) {
        self.id = id
        self.startNodeID = startNodeID
        self.entryNodeIDs = entryNodeIDs
        self.nodes = nodes
    }

    init(graph: DialogueGraph) {
        self.id = graph.id
        self.startNodeID = graph.startNodeID
        self.entryNodeIDs = graph.entryNodeIDs.isEmpty ? nil : graph.entryNodeIDs
        self.nodes = graph.nodes
    }

    var graph: DialogueGraph {
        DialogueGraph(
            id: id,
            startNodeID: startNodeID,
            entryNodeIDs: entryNodeIDs ?? [],
            nodes: nodes
        )
    }
}

enum DialogueGraphLoaderError: Error, Equatable, CustomStringConvertible {
    case unsupportedSchemaVersion(found: Int, supported: Int)
    case resourceNotFound(id: String)
    case emptyGraph(id: String)
    case missingStartNode(graphID: String, startNodeID: String)
    case graphNotInCatalog(graphID: String, catalog: String)
    case duplicateNodeID(graphID: String, nodeID: String)
    case duplicateGraphID(catalog: String, graphID: String)
    case conditionTooDeep(graphID: String, nodeID: String, depth: Int, limit: Int)
    case missingEntryNode(graphID: String, entryNodeID: String)
    case conditionalStartNode(graphID: String, startNodeID: String)

    var description: String {
        switch self {
        case .unsupportedSchemaVersion(let found, let supported):
            "Dialogue schema version \(found) is not supported (expected \(supported))"
        case .resourceNotFound(let id):
            "Dialogue graph resource not found for id '\(id)'"
        case .emptyGraph(let id):
            "Dialogue graph '\(id)' has no nodes"
        case .missingStartNode(let graphID, let startNodeID):
            "Dialogue graph '\(graphID)' is missing start node '\(startNodeID)'"
        case .graphNotInCatalog(let graphID, let catalog):
            "Dialogue graph '\(graphID)' is not present in catalog '\(catalog)'"
        case .duplicateNodeID(let graphID, let nodeID):
            "Dialogue graph '\(graphID)' authors node '\(nodeID)' more than once"
        case .duplicateGraphID(let catalog, let graphID):
            "Dialogue catalog '\(catalog)' authors graph '\(graphID)' more than once"
        case .conditionTooDeep(let graphID, let nodeID, let depth, let limit):
            "Dialogue graph '\(graphID)' node '\(nodeID)' nests a condition \(depth) deep (limit \(limit))"
        case .missingEntryNode(let graphID, let entryNodeID):
            "Dialogue graph '\(graphID)' lists entry node '\(entryNodeID)', which does not exist"
        case .conditionalStartNode(let graphID, let startNodeID):
            "Dialogue graph '\(graphID)' gates its start node '\(startNodeID)'; the entry "
                + "fallback ignores that condition — list the node in entryNodeIDs instead"
        }
    }
}

// MARK: - Loader

/// Decodes versioned dialogue JSON into pure `DialogueGraph` values.
/// Resolves optional string-table keys at load time (IE strref analogue).
/// SpriteKit-free; safe for RainShadowCore and unit tests.
enum DialogueGraphLoader {
    /// Decode an authored document (keys and/or inline prose).
    static func decodeAuthoredDocument(_ data: Data) throws -> AuthoredDialogueDocument {
        let decoder = JSONDecoder()
        let document = try decoder.decode(AuthoredDialogueDocument.self, from: data)
        guard document.schemaVersion == DialogueDocument.currentSchemaVersion else {
            throw DialogueGraphLoaderError.unsupportedSchemaVersion(
                found: document.schemaVersion,
                supported: DialogueDocument.currentSchemaVersion
            )
        }
        return document
    }

    /// Decode and resolve into a runtime graph (default string table when keys are used).
    static func decode(
        _ data: Data,
        stringTable: DialogueStringTable? = nil
    ) throws -> DialogueGraph {
        let authored = try decodeAuthoredDocument(data)
        let table = try resolveStringTable(authored.stringTable, override: stringTable)
        return try table.resolve(authored)
    }

    /// Validate a resolved document into a runtime graph (empty / start-node checks).
    static func validate(_ document: DialogueDocument) throws -> DialogueGraph {
        try makeGraph(from: document)
    }

    /// Decode an authored multi-graph catalog.
    static func decodeAuthoredCatalog(_ data: Data) throws -> AuthoredDialogueCatalogDocument {
        let decoder = JSONDecoder()
        let catalog = try decoder.decode(AuthoredDialogueCatalogDocument.self, from: data)
        guard catalog.schemaVersion == DialogueCatalogDocument.currentSchemaVersion else {
            throw DialogueGraphLoaderError.unsupportedSchemaVersion(
                found: catalog.schemaVersion,
                supported: DialogueCatalogDocument.currentSchemaVersion
            )
        }
        return catalog
    }

    /// Decode and resolve a multi-graph catalog.
    static func decodeCatalog(
        _ data: Data,
        stringTable: DialogueStringTable? = nil,
        catalogName: String = "<catalog>"
    ) throws -> [String: DialogueGraph] {
        let authored = try decodeAuthoredCatalog(data)
        let table = try resolveStringTable(authored.stringTable, override: stringTable)
        var result: [String: DialogueGraph] = [:]
        for entry in authored.graphs {
            let document = AuthoredDialogueDocument(
                schemaVersion: DialogueDocument.currentSchemaVersion,
                id: entry.id,
                startNodeID: entry.startNodeID,
                entryNodeIDs: entry.entryNodeIDs ?? [],
                nodes: entry.nodes
            )
            let graph = try table.resolve(document)
            // Last-wins used to hide a duplicated catalog id entirely: one graph simply
            // disappeared and the facade's "fail fast if missing" never fired.
            guard result.updateValue(graph, forKey: graph.id) == nil else {
                throw DialogueGraphLoaderError.duplicateGraphID(
                    catalog: catalogName,
                    graphID: graph.id
                )
            }
        }
        return result
    }

    /// Load a multi-graph catalog by resource base name (without `.json`).
    static func loadCatalog(
        resourceName: String,
        bundle: Bundle? = nil,
        stringTable: DialogueStringTable? = nil
    ) throws -> [String: DialogueGraph] {
        let data = try resourceData(resourceName: resourceName, bundle: bundle)
        return try decodeCatalog(data, stringTable: stringTable, catalogName: resourceName)
    }

    /// Load one graph from a catalog resource (cached by graph id).
    static func loadFromCatalog(
        graphID: String,
        catalogResourceName: String,
        bundle: Bundle? = nil,
        stringTable: DialogueStringTable? = nil
    ) throws -> DialogueGraph {
        cacheLock.lock()
        if let hit = graphCache[graphID] {
            cacheLock.unlock()
            return hit
        }
        cacheLock.unlock()

        let byID = try loadCatalog(
            resourceName: catalogResourceName,
            bundle: bundle,
            stringTable: stringTable
        )
        guard let graph = byID[graphID] else {
            throw DialogueGraphLoaderError.graphNotInCatalog(
                graphID: graphID,
                catalog: catalogResourceName
            )
        }
        cacheLock.lock()
        for (id, g) in byID {
            graphCache[id] = g
        }
        cacheLock.unlock()
        return graph
    }

    /// Encode a **resolved** graph as inline prose (pretty-printed for authoring dumps).
    static func encode(
        _ graph: DialogueGraph,
        schemaVersion: Int = DialogueDocument.currentSchemaVersion,
        prettyPrinted: Bool = true
    ) throws -> Data {
        let document = DialogueDocument(graph: graph, schemaVersion: schemaVersion)
        let encoder = JSONEncoder()
        if prettyPrinted {
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        }
        return try encoder.encode(document)
    }

    /// Bundle used for shipped dialogue resources (SPM tests → module; app → main).
    static var resourceBundle: Bundle {
        #if SWIFT_PACKAGE
        .module
        #else
        .main
        #endif
    }

    /// Load by graph id from a resource bundle (defaults to `resourceBundle`).
    ///
    /// Default resource base name: `defaultResourceName(for:)` + `.json`
    /// (e.g. `case.empty-coat.intro` → `empty-coat.intro.dialogue.json`).
    static func load(
        id: String,
        bundle: Bundle? = nil,
        resourceName: String? = nil,
        stringTable: DialogueStringTable? = nil
    ) throws -> DialogueGraph {
        let name = resourceName ?? defaultResourceName(for: id)
        let data = try resourceData(resourceName: name, bundle: bundle, lookupID: id)
        return try decode(data, stringTable: stringTable)
    }

    /// Shared resource lookup for dialogue JSON and string tables.
    static func resourceData(
        resourceName name: String,
        bundle: Bundle?,
        lookupID: String? = nil
    ) throws -> Data {
        let searchBundles: [Bundle] = {
            if let bundle { return [bundle] }
            #if SWIFT_PACKAGE
            return [.module, .main]
            #else
            return [.main]
            #endif
        }()
        for candidate in searchBundles {
            if let url = candidate.url(forResource: name, withExtension: "json", subdirectory: "Dialogue")
                ?? candidate.url(forResource: name, withExtension: "json")
            {
                return try Data(contentsOf: url)
            }
        }
        if let url = developmentResourceURL(resourceName: name) {
            return try Data(contentsOf: url)
        }
        throw DialogueGraphLoaderError.resourceNotFound(id: lookupID ?? name)
    }

    /// Load JSON from an explicit file URL (tests / tooling).
    static func load(
        contentsOf url: URL,
        stringTable: DialogueStringTable? = nil
    ) throws -> DialogueGraph {
        let data = try Data(contentsOf: url)
        return try decode(data, stringTable: stringTable)
    }

    /// Cached load by graph id (first success wins for process lifetime).
    /// Lock-protected; `nonisolated(unsafe)` is intentional for the dictionary storage.
    private static let cacheLock = NSLock()
    nonisolated(unsafe) private static var graphCache: [String: DialogueGraph] = [:]

    static func loadCached(
        id: String,
        bundle: Bundle? = nil,
        resourceName: String? = nil,
        stringTable: DialogueStringTable? = nil
    ) throws -> DialogueGraph {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        if let hit = graphCache[id] {
            return hit
        }
        let graph = try load(
            id: id,
            bundle: bundle,
            resourceName: resourceName,
            stringTable: stringTable
        )
        graphCache[id] = graph
        return graph
    }

    /// `RainShadow Shared/Resources/Dialogue/<name>.json` relative to this source file.
    private static func developmentResourceURL(resourceName: String) -> URL? {
        let here = URL(fileURLWithPath: #filePath)
        let sharedRoot = here
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = sharedRoot
            .appendingPathComponent("Resources/Dialogue/\(resourceName).json", isDirectory: false)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    // MARK: - Internals

    private static func resolveStringTable(
        _ documentOverride: String?,
        override: DialogueStringTable?
    ) throws -> DialogueStringTable {
        if let override { return override }
        let name = documentOverride ?? DialogueStringTable.defaultResourceName
        // Prefer the shipped table; fall back to empty so pure-inline fixtures still load.
        do {
            return try DialogueStringTable.load(resourceName: name)
        } catch DialogueGraphLoaderError.resourceNotFound {
            if documentOverride != nil {
                throw DialogueGraphLoaderError.resourceNotFound(id: name)
            }
            return .empty
        }
    }

    private static func makeGraph(from document: DialogueDocument) throws -> DialogueGraph {
        let graph = document.graph
        try graph.validateAuthoring()
        return graph
    }

    /// `case.empty-coat.intro` → `empty-coat.intro.dialogue` (strip optional `case.` prefix).
    static func defaultResourceName(for graphID: String) -> String {
        let trimmed = graphID.hasPrefix("case.")
            ? String(graphID.dropFirst("case.".count))
            : graphID
        return "\(trimmed).dialogue"
    }
}
