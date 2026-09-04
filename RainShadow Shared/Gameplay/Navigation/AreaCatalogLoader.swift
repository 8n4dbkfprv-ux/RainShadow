import Foundation

// MARK: - Errors

enum AreaCatalogError: Error, Equatable, CustomStringConvertible {
    case unsupportedSchemaVersion(found: Int, supported: Int)
    case resourceNotFound(name: String)
    case duplicateAreaID(AreaID)
    case duplicateEntranceName(area: AreaID, name: String)
    case duplicateRegionID(area: AreaID, regionID: String)
    case areaWithoutEntrance(AreaID)
    case degenerateRegion(area: AreaID, regionID: String, vertexCount: Int)
    case travelRegionWithoutDestination(area: AreaID, regionID: String)
    case unknownTravelDestination(area: AreaID, regionID: String, destination: AreaID)
    case unknownTravelEntrance(area: AreaID, regionID: String, destination: AreaID, entrance: String)
    case emptyCatalog
    case duplicateDoorID(area: AreaID, doorID: String)
    case duplicateAnimationID(area: AreaID, animationID: String)

    var description: String {
        switch self {
        case .unsupportedSchemaVersion(let found, let supported):
            "Area schema version \(found) is not supported (expected \(supported))"
        case .resourceNotFound(let name):
            "Area resource '\(name).area.json' not found"
        case .duplicateAreaID(let id):
            "Area '\(id)' is authored more than once"
        case .duplicateEntranceName(let area, let name):
            "Area '\(area)' authors entrance '\(name)' more than once"
        case .duplicateRegionID(let area, let regionID):
            "Area '\(area)' authors region '\(regionID)' more than once"
        case .areaWithoutEntrance(let area):
            "Area '\(area)' authors no entrance, so nothing can arrive in it"
        case .degenerateRegion(let area, let regionID, let vertexCount):
            "Region '\(regionID)' in area '\(area)' has \(vertexCount) vertices; "
                + "an outline needs at least 3"
        case .travelRegionWithoutDestination(let area, let regionID):
            "Travel region '\(regionID)' in area '\(area)' names no destination"
        case .unknownTravelDestination(let area, let regionID, let destination):
            "Travel region '\(regionID)' in area '\(area)' points at area "
                + "'\(destination)', which is not in the catalog"
        case .unknownTravelEntrance(let area, let regionID, let destination, let entrance):
            "Travel region '\(regionID)' in area '\(area)' arrives at entrance "
                + "'\(entrance)' of '\(destination)', which that area does not author — "
                + "the transition would drop the player at an unauthored point"
        case .emptyCatalog:
            "The area catalog is empty"
        case .duplicateDoorID(let area, let doorID):
            "Area '\(area)' authors door '\(doorID)' more than once"
        case .duplicateAnimationID(let area, let animationID):
            "Area '\(area)' authors animation '\(animationID)' more than once"
        }
    }
}

// MARK: - Document

/// On-disk representation of one area file. Mirrors `ItemCatalogDocument`:
/// the runtime consumes `AreaDefinition`, this wrapper carries schema versioning.
struct AreaDocument: Equatable, Codable, Sendable {
    /// Supported loader schema. Bump only with a migration path.
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var area: AreaDefinition

    init(schemaVersion: Int = AreaDocument.currentSchemaVersion, area: AreaDefinition) {
        self.schemaVersion = schemaVersion
        self.area = area
    }
}

// MARK: - Runtime catalog

/// Resolved areas, keyed by id. Pure value type; SpriteKit-free.
///
/// Cross-area references are checked once here rather than at travel time, so a
/// door pointing at a renamed entrance is an authoring error the suite catches
/// instead of a transition that drops the player somewhere unauthored.
struct AreaCatalog: Equatable, Sendable {
    /// Authored order, for deterministic iteration in tests and tooling.
    let orderedIDs: [AreaID]
    private let areasByID: [AreaID: AreaDefinition]

    init(orderedIDs: [AreaID], areasByID: [AreaID: AreaDefinition]) {
        self.orderedIDs = orderedIDs
        self.areasByID = areasByID
    }

    var isEmpty: Bool { orderedIDs.isEmpty }
    var count: Int { orderedIDs.count }

    var allAreas: [AreaDefinition] {
        orderedIDs.compactMap { areasByID[$0] }
    }

    func area(for id: AreaID) -> AreaDefinition? {
        areasByID[id]
    }

    /// Throwing lookup for call sites that cannot proceed without the area.
    func require(_ id: AreaID) throws -> AreaDefinition {
        guard let area = areasByID[id] else {
            throw AreaCatalogError.resourceNotFound(name: id.rawValue)
        }
        return area
    }
}

// MARK: - Loader

/// Decodes versioned area JSON into pure `AreaCatalog` values.
///
/// Deliberately shaped after `ItemCatalogLoader` and `DialogueGraphLoader`, down
/// to the bundle search order and the `#filePath` development fallback, so an
/// area resolves the same way an item or a conversation already does.
enum AreaCatalogLoader {
    /// Resource subdirectory and file suffix. An area file is
    /// `Resources/Areas/<id>.area.json`, so the basename is the `AreaID` —
    /// `ProjectStructure.md` §7's rule that JSON basenames are stable ids.
    static let resourceSubdirectory = "Areas"
    static let resourceSuffix = ".area"

    static var resourceBundle: Bundle {
        #if SWIFT_PACKAGE
        .module
        #else
        .main
        #endif
    }

    // MARK: Decoding

    static func decodeDocument(_ data: Data) throws -> AreaDocument {
        let document = try JSONDecoder().decode(AreaDocument.self, from: data)
        guard document.schemaVersion == AreaDocument.currentSchemaVersion else {
            throw AreaCatalogError.unsupportedSchemaVersion(
                found: document.schemaVersion,
                supported: AreaDocument.currentSchemaVersion
            )
        }
        return document
    }

    static func decodeArea(_ data: Data) throws -> AreaDefinition {
        try decodeDocument(data).area
    }

    // MARK: Validation

    /// Per-area checks that need no knowledge of the rest of the catalog.
    static func validateArea(_ area: AreaDefinition) throws {
        guard !area.entrances.isEmpty else {
            throw AreaCatalogError.areaWithoutEntrance(area.id)
        }

        var seenEntrances: Set<String> = []
        for entrance in area.entrances {
            guard seenEntrances.insert(entrance.name).inserted else {
                throw AreaCatalogError.duplicateEntranceName(
                    area: area.id,
                    name: entrance.name
                )
            }
        }

        var seenRegions: Set<String> = []
        for region in area.regions {
            guard seenRegions.insert(region.id).inserted else {
                throw AreaCatalogError.duplicateRegionID(area: area.id, regionID: region.id)
            }
            guard region.polygon.count >= 3 else {
                throw AreaCatalogError.degenerateRegion(
                    area: area.id,
                    regionID: region.id,
                    vertexCount: region.polygon.count
                )
            }
            if region.kind == .travel, region.travel == nil {
                throw AreaCatalogError.travelRegionWithoutDestination(
                    area: area.id,
                    regionID: region.id
                )
            }
        }

        var seenDoors: Set<String> = []
        for door in area.doors {
            guard seenDoors.insert(door.id).inserted else {
                throw AreaCatalogError.duplicateDoorID(area: area.id, doorID: door.id)
            }
        }

        var seenAnimations: Set<String> = []
        for animation in area.animations {
            guard seenAnimations.insert(animation.id).inserted else {
                throw AreaCatalogError.duplicateAnimationID(
                    area: area.id,
                    animationID: animation.id
                )
            }
        }
    }

    /// Whole-catalog checks: every travel region resolves to a real area and a
    /// real entrance in it.
    static func validate(_ areas: [AreaDefinition]) throws -> AreaCatalog {
        guard !areas.isEmpty else { throw AreaCatalogError.emptyCatalog }

        var areasByID: [AreaID: AreaDefinition] = [:]
        var orderedIDs: [AreaID] = []
        areasByID.reserveCapacity(areas.count)
        orderedIDs.reserveCapacity(areas.count)

        for area in areas {
            guard areasByID[area.id] == nil else {
                throw AreaCatalogError.duplicateAreaID(area.id)
            }
            try validateArea(area)
            areasByID[area.id] = area
            orderedIDs.append(area.id)
        }

        for area in areas {
            for region in area.travelRegions {
                guard let travel = region.travel else { continue }
                guard let destination = areasByID[travel.destination] else {
                    throw AreaCatalogError.unknownTravelDestination(
                        area: area.id,
                        regionID: region.id,
                        destination: travel.destination
                    )
                }
                guard destination.entrance(named: travel.entrance) != nil else {
                    throw AreaCatalogError.unknownTravelEntrance(
                        area: area.id,
                        regionID: region.id,
                        destination: travel.destination,
                        entrance: travel.entrance
                    )
                }
            }
        }

        return AreaCatalog(orderedIDs: orderedIDs, areasByID: areasByID)
    }

    // MARK: Loading

    /// Load one area by id.
    static func load(_ id: AreaID, bundle: Bundle? = nil) throws -> AreaDefinition {
        try decodeArea(resourceData(areaID: id, bundle: bundle))
    }

    /// Load a catalog from an explicit id list, in the order given.
    static func load(_ ids: [AreaID], bundle: Bundle? = nil) throws -> AreaCatalog {
        try validate(ids.map { try load($0, bundle: bundle) })
    }

    /// Load area JSON from an explicit file URL (tests / tooling).
    static func load(contentsOf url: URL) throws -> AreaDefinition {
        try decodeArea(Data(contentsOf: url))
    }

    static func resourceData(areaID id: AreaID, bundle: Bundle?) throws -> Data {
        let name = id.rawValue + resourceSuffix
        let searchBundles: [Bundle] = {
            if let bundle { return [bundle] }
            #if SWIFT_PACKAGE
            return [.module, .main]
            #else
            return [.main]
            #endif
        }()
        for candidate in searchBundles {
            if let url = candidate.url(
                forResource: name,
                withExtension: "json",
                subdirectory: resourceSubdirectory
            ) ?? candidate.url(forResource: name, withExtension: "json") {
                return try Data(contentsOf: url)
            }
        }
        if let url = developmentResourceURL(areaID: id) {
            return try Data(contentsOf: url)
        }
        throw AreaCatalogError.resourceNotFound(name: id.rawValue)
    }

    /// `RainShadow Shared/Resources/Areas/<id>.area.json` relative to this source file.
    static func developmentResourceURL(areaID id: AreaID) -> URL? {
        let url = developmentAreasDirectory
            .appendingPathComponent("\(id.rawValue)\(resourceSuffix).json", isDirectory: false)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// `RainShadow Shared/Resources/Areas/`, used by tests and by the tooling
    /// that writes area files.
    static var developmentAreasDirectory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()     // Navigation
            .deletingLastPathComponent()     // Gameplay
            .deletingLastPathComponent()     // RainShadow Shared
            .appendingPathComponent("Resources/\(resourceSubdirectory)", isDirectory: true)
    }

    // MARK: - Cache

    /// Cached catalog load (first success wins for process lifetime).
    /// Lock-protected; `nonisolated(unsafe)` is intentional for the storage.
    private static let cacheLock = NSLock()
    nonisolated(unsafe) private static var catalogCache: [String: AreaCatalog] = [:]

    static func loadCached(_ ids: [AreaID], bundle: Bundle? = nil) throws -> AreaCatalog {
        let key = ids.map(\.rawValue).joined(separator: ",")
        cacheLock.lock()
        defer { cacheLock.unlock() }
        if let hit = catalogCache[key] {
            return hit
        }
        let catalog = try load(ids, bundle: bundle)
        catalogCache[key] = catalog
        return catalog
    }
}

// MARK: - Shipped content facade

/// Thin facade over the shipped Harborpoint areas, matching `HarborpointItems`.
///
/// The id list is authored here rather than discovered by directory scan: a
/// bundle listing is not deterministic across platforms, and an area that fails
/// to ship should be a loud missing-resource error rather than an area that
/// quietly is not in the world.
enum HarborpointAreas {
    static let office = AreaID("office_suite")
    static let openingExterior = AreaID("opening_exterior")
    static let sableRow = AreaID("city_sable_row")
    static let wharfLadder = AreaID("city_wharf_ladder")
    static let riverside = AreaID("city_riverside")
    static let harborpointPD = AreaID("city_harborpoint_pd")
    static let lilaStreet = AreaID("city_lila_street")
    static let civicRecords = AreaID("city_civic_records")
    static let shippingOfficeInterior = CityInteriorID.shippingOffice.areaID
    static let ironStairsInterior = CityInteriorID.ironStairs.areaID
    static let policeStationInterior = CityInteriorID.policeStation.areaID
    static let lilaRoomsInterior = CityInteriorID.lilaRooms.areaID
    static let recordsAnnexInterior = CityInteriorID.recordsAnnex.areaID

    /// Every area that ships, in authored order.
    static let shippedIDs: [AreaID] = [
        office,
        openingExterior,
        sableRow,
        wharfLadder,
        riverside,
        harborpointPD,
        lilaStreet,
        civicRecords,
        shippingOfficeInterior,
        ironStairsInterior,
        policeStationInterior,
        lilaRoomsInterior,
        recordsAnnexInterior
    ]

    /// The shipped catalog. Missing or malformed content is a build-time
    /// authoring error, not a runtime condition, so this traps the same way
    /// `HarborpointItems.catalog` does.
    static var catalog: AreaCatalog {
        do {
            return try AreaCatalogLoader.loadCached(shippedIDs)
        } catch {
            preconditionFailure("Shipped area catalog failed to load: \(error)")
        }
    }

    static func area(for id: AreaID) -> AreaDefinition? {
        catalog.area(for: id)
    }

    /// Trapping lookup for the scene layer, which cannot draw an area it does
    /// not have. A missing area is authoring, not a runtime condition — the
    /// same stance `HarborpointItems.catalog` takes.
    static func requireArea(_ id: AreaID) -> AreaDefinition {
        guard let area = catalog.area(for: id) else {
            preconditionFailure("No shipped area '\(id)'")
        }
        return area
    }
}
