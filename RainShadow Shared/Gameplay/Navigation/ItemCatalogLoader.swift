import Foundation

// MARK: - Errors

enum ItemCatalogError: Error, Equatable, CustomStringConvertible {
    case unsupportedSchemaVersion(found: Int, supported: Int)
    case resourceNotFound(name: String)
    case emptyCatalog(name: String)
    case duplicateItemID(catalog: String, itemID: String)
    case unknownItem(id: String)
    case unknownItemFlag(name: String)
    case stackableWornItem(itemID: String)

    var description: String {
        switch self {
        case .unsupportedSchemaVersion(let found, let supported):
            "Item catalog schema version \(found) is not supported (expected \(supported))"
        case .resourceNotFound(let name):
            "Item catalog resource '\(name).json' not found"
        case .emptyCatalog(let name):
            "Item catalog '\(name)' authors no items"
        case .duplicateItemID(let catalog, let itemID):
            "Item catalog '\(catalog)' authors item '\(itemID)' more than once"
        case .unknownItem(let id):
            "No item definition is authored for id '\(id)'"
        case .unknownItemFlag(let name):
            "Item flag '\(name)' is not a known flag"
        case .stackableWornItem(let itemID):
            "Item '\(itemID)' is worn and stacks; the engine stacks ammunition and "
                + "quick-slot consumables, never worn gear — a worn stack has no "
                + "single garment to take the wear"
        }
    }
}

// MARK: - Document

/// On-disk representation of an item package. Mirrors `DialogueDocument`:
/// the runtime consumes `ItemCatalog`, this wrapper carries schema versioning.
struct ItemCatalogDocument: Equatable, Codable, Sendable {
    /// Supported loader schema. Bump only with a migration path.
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var id: String
    var items: [ItemDefinition]

    init(
        schemaVersion: Int = ItemCatalogDocument.currentSchemaVersion,
        id: String,
        items: [ItemDefinition]
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.items = items
    }
}

// MARK: - Runtime catalog

/// Resolved item definitions, keyed by id. Pure value type; SpriteKit-free.
struct ItemCatalog: Equatable, Sendable {
    /// Authored order, for deterministic iteration in tests and tooling.
    let orderedIDs: [String]
    private let definitionsByID: [String: ItemDefinition]

    init(orderedIDs: [String], definitionsByID: [String: ItemDefinition]) {
        self.orderedIDs = orderedIDs
        self.definitionsByID = definitionsByID
    }

    var isEmpty: Bool { orderedIDs.isEmpty }
    var count: Int { orderedIDs.count }

    var allDefinitions: [ItemDefinition] {
        orderedIDs.compactMap { definitionsByID[$0] }
    }

    func definition(for id: String) -> ItemDefinition? {
        definitionsByID[id]
    }

    /// Throwing lookup for call sites that cannot proceed without the item.
    func require(_ id: String) throws -> ItemDefinition {
        guard let definition = definitionsByID[id] else {
            throw ItemCatalogError.unknownItem(id: id)
        }
        return definition
    }
}

// MARK: - Loader

/// Decodes versioned item JSON into pure `ItemCatalog` values.
///
/// Deliberately shaped after `DialogueGraphLoader`, down to the bundle search
/// order and the `#filePath` development fallback, so shipped content and SPM
/// tests resolve resources the same way for items as they already do for
/// conversations.
enum ItemCatalogLoader {
    /// The shipped catalog's resource base name.
    static let defaultResourceName = "harborpoint.items"

    /// Bundle used for shipped item resources (SPM tests → module; app → main).
    static var resourceBundle: Bundle {
        #if SWIFT_PACKAGE
        .module
        #else
        .main
        #endif
    }

    static func decodeDocument(_ data: Data) throws -> ItemCatalogDocument {
        let document = try JSONDecoder().decode(ItemCatalogDocument.self, from: data)
        guard document.schemaVersion == ItemCatalogDocument.currentSchemaVersion else {
            throw ItemCatalogError.unsupportedSchemaVersion(
                found: document.schemaVersion,
                supported: ItemCatalogDocument.currentSchemaVersion
            )
        }
        return document
    }

    /// Decode and validate into a runtime catalog.
    static func decode(_ data: Data) throws -> ItemCatalog {
        try validate(decodeDocument(data))
    }

    static func validate(_ document: ItemCatalogDocument) throws -> ItemCatalog {
        guard !document.items.isEmpty else {
            throw ItemCatalogError.emptyCatalog(name: document.id)
        }

        var definitionsByID: [String: ItemDefinition] = [:]
        var orderedIDs: [String] = []
        definitionsByID.reserveCapacity(document.items.count)
        orderedIDs.reserveCapacity(document.items.count)

        for item in document.items {
            guard definitionsByID[item.id] == nil else {
                throw ItemCatalogError.duplicateItemID(catalog: document.id, itemID: item.id)
            }
            // The engine stacks ammunition and quick-slot consumables (potions
            // stack in BG's quick slots) but never worn gear, which has no
            // per-garment identity a single paperdoll slot could hold.
            if item.stacks, item.equippableSlots.contains(where: \.isWorn) {
                throw ItemCatalogError.stackableWornItem(itemID: item.id)
            }
            definitionsByID[item.id] = item
            orderedIDs.append(item.id)
        }

        return ItemCatalog(orderedIDs: orderedIDs, definitionsByID: definitionsByID)
    }

    /// Load a catalog by resource base name.
    static func load(
        resourceName: String? = nil,
        bundle: Bundle? = nil
    ) throws -> ItemCatalog {
        let name = resourceName ?? defaultResourceName
        return try decode(resourceData(resourceName: name, bundle: bundle))
    }

    /// Load JSON from an explicit file URL (tests / tooling).
    static func load(contentsOf url: URL) throws -> ItemCatalog {
        try decode(Data(contentsOf: url))
    }

    /// Shared resource lookup for item JSON.
    static func resourceData(resourceName name: String, bundle: Bundle?) throws -> Data {
        let searchBundles: [Bundle] = {
            if let bundle { return [bundle] }
            #if SWIFT_PACKAGE
            return [.module, .main]
            #else
            return [.main]
            #endif
        }()
        for candidate in searchBundles {
            if let url = candidate.url(forResource: name, withExtension: "json", subdirectory: "Items")
                ?? candidate.url(forResource: name, withExtension: "json")
            {
                return try Data(contentsOf: url)
            }
        }
        if let url = developmentResourceURL(resourceName: name) {
            return try Data(contentsOf: url)
        }
        throw ItemCatalogError.resourceNotFound(name: name)
    }

    /// `RainShadow Shared/Resources/Items/<name>.json` relative to this source file.
    private static func developmentResourceURL(resourceName: String) -> URL? {
        let here = URL(fileURLWithPath: #filePath)
        let sharedRoot = here
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = sharedRoot
            .appendingPathComponent("Resources/Items/\(resourceName).json", isDirectory: false)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    // MARK: - Cache

    /// Cached load by resource name (first success wins for process lifetime).
    /// Lock-protected; `nonisolated(unsafe)` is intentional for the dictionary storage.
    private static let cacheLock = NSLock()
    nonisolated(unsafe) private static var catalogCache: [String: ItemCatalog] = [:]

    static func loadCached(
        resourceName: String? = nil,
        bundle: Bundle? = nil
    ) throws -> ItemCatalog {
        let name = resourceName ?? defaultResourceName
        cacheLock.lock()
        defer { cacheLock.unlock() }
        if let hit = catalogCache[name] {
            return hit
        }
        let catalog = try load(resourceName: name, bundle: bundle)
        catalogCache[name] = catalog
        return catalog
    }
}

// MARK: - Shipped content facade

/// Thin facade over the shipped Harborpoint catalog, matching the shape of
/// `OfficeHotspotDialogue` — content packages get a named accessor so call sites
/// never spell a resource name.
enum HarborpointItems {
    /// The shipped catalog. Missing or malformed content is a build-time authoring
    /// error, not a runtime condition, so this traps in the same spirit as the
    /// `assertionFailure` the UI uses for missing art.
    static var catalog: ItemCatalog {
        do {
            return try ItemCatalogLoader.loadCached()
        } catch {
            preconditionFailure("Shipped item catalog failed to load: \(error)")
        }
    }

    static func definition(for id: String) -> ItemDefinition? {
        catalog.definition(for: id)
    }

    /// The six items the case bag starts with, in painted order.
    static let starterItemIDs = [
        "service-revolver",
        "case-notes",
        "brass-key",
        "flashlight",
        "wallet",
        "cigarette-case"
    ]
}
