import CoreGraphics
import Foundation

// MARK: - Identity

/// Stable resref-like identifier for one area, matching its `.area.json`
/// basename. Baldur's Gate keys every cross-area reference — travel regions,
/// world-map entries, saved variables — on the area's eight-character resref
/// rather than on a position in a list, so a renumbered catalog cannot silently
/// repoint a door. `AreaID` is that resref: authored once, never derived.
struct AreaID: Hashable, Sendable, RawRepresentable, CustomStringConvertible {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    var description: String { rawValue }
}

extension AreaID: Codable {
    init(from decoder: Decoder) throws {
        rawValue = try decoder.singleValueContainer().decode(String.self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

// MARK: - Geometry

/// JSON point. Keys match the `city_layout.json` dump the offline previewer
/// already reads (`CityLayoutDumpTests`), so one encoding serves both.
struct AreaPoint: Hashable, Codable, Sendable {
    var x: CGFloat
    var y: CGFloat

    init(x: CGFloat, y: CGFloat) {
        self.x = x
        self.y = y
    }

    init(_ point: CGPoint) {
        self.init(x: point.x, y: point.y)
    }

    var cgPoint: CGPoint { CGPoint(x: x, y: y) }
}

/// JSON rect, `x`/`y` at the minimum corner.
struct AreaRect: Hashable, Codable, Sendable {
    var x: CGFloat
    var y: CGFloat
    var w: CGFloat
    var h: CGFloat

    init(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat) {
        self.x = x
        self.y = y
        self.w = w
        self.h = h
    }

    init(_ rect: CGRect) {
        let standardized = rect.standardized
        self.init(
            x: standardized.minX,
            y: standardized.minY,
            w: standardized.width,
            h: standardized.height
        )
    }

    var cgRect: CGRect { CGRect(x: x, y: y, width: w, height: h) }
}

struct AreaSize: Hashable, Codable, Sendable {
    var w: CGFloat
    var h: CGFloat

    init(w: CGFloat, h: CGFloat) {
        self.w = w
        self.h = h
    }

    init(_ size: CGSize) {
        self.init(w: size.width, h: size.height)
    }

    var cgSize: CGSize { CGSize(width: w, height: h) }
}

// MARK: - Sections

/// Infinity Engine area-type distinction. BG's `.ARE` header carries a bitfield
/// (outdoor, day/night, weather, city, forest, dungeon); RainShadow needs only
/// the interior/exterior split that decides weather, lighting preset and
/// whether the world map can reach the area directly.
enum AreaKind: String, Codable, Sendable {
    case interior
    case exterior
}

/// A named arrival point. Every transition into an area names an entrance, the
/// way a BG area link or travel region carries an entry-point name — which is
/// what lets one area be entered from four streets and a staircase without the
/// destination knowing who sent the party.
struct AreaEntrance: Hashable, Codable, Sendable {
    /// Authoring convention inherited from `CityMapEdge.arrivalKey`:
    /// `from.north`, `from.office`, or `default`.
    var name: String
    var point: AreaPoint
    /// Facing in degrees, measured like `ActorLocomotion`'s facing bins.
    var facing: CGFloat?

    /// The entrance used when a transition names none.
    static let defaultName = "default"

    init(name: String, point: AreaPoint, facing: CGFloat? = nil) {
        self.name = name
        self.point = point
        self.facing = facing
    }
}

/// BG splits `.ARE` regions into info points, proximity triggers and travel
/// regions. The three share an outline and differ only in what entering or
/// clicking them does, which is exactly how they are modelled here.
enum AreaRegionKind: String, Codable, Sendable {
    /// Walk up and inspect. The office's hotspots are these.
    case info
    /// Fires an area-script block on entry.
    case trigger
    /// Moves the player to another area's named entrance.
    case travel
}

/// A travel region's payload — BG's area-link fields that survive into an
/// `.ARE`: where you end up, and by which door.
struct AreaTravel: Hashable, Codable, Sendable {
    var destination: AreaID
    var entrance: String

    init(destination: AreaID, entrance: String = AreaEntrance.defaultName) {
        self.destination = destination
        self.entrance = entrance
    }
}

/// One region outline. Authored as a polygon because BG regions are polygons;
/// a rect is a legal four-vertex polygon, so every existing `hitArea` converts
/// without reshaping.
struct AreaRegion: Hashable, Codable, Sendable {
    var id: String
    var kind: AreaRegionKind
    var label: String?
    var polygon: [AreaPoint]
    /// Where the player stands to use this region. Per `AGENTS.md`, this belongs
    /// on the walkable side the region faces — never on the door sprite, which
    /// is painted on the facade and therefore sits inside the building's
    /// obstacle. Authored from `nearestWalkablePoint`, unrounded.
    var approachPoint: AreaPoint?
    var travel: AreaTravel?
    /// Inspect prose for an `.info` region.
    var observation: String?
    /// Area-script block fired by a `.trigger` region.
    var scriptBlock: String?
    /// Case flag that must be set before the region does anything.
    var requiresFlag: String?
    /// Line shown when `requiresFlag` is unmet.
    var lockedLine: String?

    init(
        id: String,
        kind: AreaRegionKind,
        label: String? = nil,
        polygon: [AreaPoint],
        approachPoint: AreaPoint? = nil,
        travel: AreaTravel? = nil,
        observation: String? = nil,
        scriptBlock: String? = nil,
        requiresFlag: String? = nil,
        lockedLine: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.label = label
        self.polygon = polygon
        self.approachPoint = approachPoint
        self.travel = travel
        self.observation = observation
        self.scriptBlock = scriptBlock
        self.requiresFlag = requiresFlag
        self.lockedLine = lockedLine
    }

    /// Convenience for the many regions that really are rectangles.
    init(
        id: String,
        kind: AreaRegionKind,
        label: String? = nil,
        rect: CGRect,
        approachPoint: AreaPoint? = nil,
        travel: AreaTravel? = nil,
        observation: String? = nil,
        scriptBlock: String? = nil,
        requiresFlag: String? = nil,
        lockedLine: String? = nil
    ) {
        let r = rect.standardized
        self.init(
            id: id,
            kind: kind,
            label: label,
            polygon: [
                AreaPoint(x: r.minX, y: r.minY),
                AreaPoint(x: r.maxX, y: r.minY),
                AreaPoint(x: r.maxX, y: r.maxY),
                AreaPoint(x: r.minX, y: r.maxY)
            ],
            approachPoint: approachPoint,
            travel: travel,
            observation: observation,
            scriptBlock: scriptBlock,
            requiresFlag: requiresFlag,
            lockedLine: lockedLine
        )
    }

    /// Axis-aligned bound, used as the cheap reject before the polygon test —
    /// BG stores this alongside the vertex range for the same reason.
    var boundingBox: CGRect {
        guard let first = polygon.first else { return .null }
        var minX = first.x, maxX = first.x
        var minY = first.y, maxY = first.y
        for vertex in polygon.dropFirst() {
            minX = min(minX, vertex.x)
            maxX = max(maxX, vertex.x)
            minY = min(minY, vertex.y)
            maxY = max(maxY, vertex.y)
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    /// Even-odd crossing test. The `>` comparison on both endpoints makes each
    /// edge half-open in y, so a horizontal ray through a shared vertex counts
    /// one crossing rather than two — which is what a click test wants: a point
    /// on the boundary between two abutting regions hits exactly one of them.
    func contains(_ point: CGPoint) -> Bool {
        guard polygon.count >= 3, boundingBox.contains(point) else { return false }
        var isInside = false
        var j = polygon.count - 1
        for i in polygon.indices {
            let a = polygon[i]
            let b = polygon[j]
            if (a.y > point.y) != (b.y > point.y) {
                let t = (point.y - a.y) / (b.y - a.y)
                if point.x < a.x + t * (b.x - a.x) {
                    isInside.toggle()
                }
            }
            j = i
        }
        return isInside
    }
}

/// A placed background object. Carries the depth-slicing fields
/// `CityDistrictScene.addDepthSlicedSprite` needs so a near-side facade can
/// occlude the far street while the player walks in front of it — RainShadow's
/// stand-in for the wall polygons a `.WED` would carry.
struct AreaProp: Hashable, Codable, Sendable {
    var textureName: String
    var groundPoint: AreaPoint
    var scale: CGFloat
    var anchorY: CGFloat
    var depthBias: CGFloat
    /// Draw at an explicit world size instead of `setScale`.
    var worldSize: AreaSize?
    /// Vertical strip width, in world units, for depth-sliced facades.
    var depthSliceWidth: CGFloat?
    /// Lot whose north kerb is the sort key for those strips.
    var depthSortLot: String?

    init(
        textureName: String,
        groundPoint: AreaPoint,
        scale: CGFloat,
        anchorY: CGFloat,
        depthBias: CGFloat,
        worldSize: AreaSize? = nil,
        depthSliceWidth: CGFloat? = nil,
        depthSortLot: String? = nil
    ) {
        self.textureName = textureName
        self.groundPoint = groundPoint
        self.scale = scale
        self.anchorY = anchorY
        self.depthBias = depthBias
        self.worldSize = worldSize
        self.depthSliceWidth = depthSliceWidth
        self.depthSortLot = depthSortLot
    }
}

/// A creature placed in the area. BG's `.ARE` actor entry names a `CRE` and a
/// position; the scene layer owns the sprite classes, so `kind` names which one
/// to build rather than describing it here.
struct AreaActor: Hashable, Codable, Sendable {
    var id: String
    /// `detective`, `client`, … — resolved by the scene layer's actor factory.
    var kind: String
    var point: AreaPoint
    var facing: CGFloat?
    /// Case flag gating the actor's presence, standing in for BG's schedule.
    var requiresFlag: String?

    init(
        id: String,
        kind: String,
        point: AreaPoint,
        facing: CGFloat? = nil,
        requiresFlag: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.point = point
        self.facing = facing
        self.requiresFlag = requiresFlag
    }
}

/// A searchable receptacle. Wraps the shipped `LootContainerDefinition` so the
/// resolve-once loot rules stay exactly where they are and the area only adds
/// placement.
struct AreaContainer: Hashable, Codable, Sendable {
    var id: String
    var label: String
    var hitArea: AreaRect
    var approachPoint: AreaPoint
    var loot: LootContainerDefinition

    init(
        id: String,
        label: String,
        hitArea: AreaRect,
        approachPoint: AreaPoint,
        loot: LootContainerDefinition
    ) {
        self.id = id
        self.label = label
        self.hitArea = hitArea
        self.approachPoint = approachPoint
        self.loot = loot
    }
}

/// A door leaf that stamps and clears in place. `NavigationMap` already
/// supports this without rebuilding the search map; the area supplies the rects.
struct AreaDoor: Hashable, Codable, Sendable {
    var id: String
    var textureName: String?
    /// Blocking footprint while shut.
    var closedObstacle: AreaRect
    /// Blocking footprint while open; omit when an open door blocks nothing.
    var openObstacle: AreaRect?
    var startsClosed: Bool

    init(
        id: String,
        textureName: String? = nil,
        closedObstacle: AreaRect,
        openObstacle: AreaRect? = nil,
        startsClosed: Bool = true
    ) {
        self.id = id
        self.textureName = textureName
        self.closedObstacle = closedObstacle
        self.openObstacle = openObstacle
        self.startsClosed = startsClosed
    }
}

/// An automap marker — BG's automap note, RainShadow's `PointOfInterest`.
struct AreaNote: Hashable, Codable, Sendable {
    var label: String
    var point: AreaPoint
    /// sRGB components, converted to a platform colour at the UI layer.
    var colorRGBA: [CGFloat]

    init(label: String, point: AreaPoint, colorRGBA: [CGFloat]) {
        self.label = label
        self.point = point
        self.colorRGBA = colorRGBA
    }
}

/// A placed sound. A `point`-less ambient is the area-wide bed BG calls a
/// global ambient; one with a point and radius is local.
struct AreaAmbient: Hashable, Codable, Sendable {
    var id: String
    var assetName: String
    var point: AreaPoint?
    var radius: CGFloat?
    var volume: CGFloat
    var isLooping: Bool

    init(
        id: String,
        assetName: String,
        point: AreaPoint? = nil,
        radius: CGFloat? = nil,
        volume: CGFloat = 1,
        isLooping: Bool = true
    ) {
        self.id = id
        self.assetName = assetName
        self.point = point
        self.radius = radius
        self.volume = volume
        self.isLooping = isLooping
    }
}

/// Pathfinding agent footprint, authored per area because the office's obstacle
/// art already includes floor-contact clearance and the street's does not.
/// Mirrors `NavigationAgentProfile`, which is not itself `Codable`.
struct AreaAgentProfile: Hashable, Codable, Sendable {
    var halfWidth: CGFloat
    var halfHeight: CGFloat

    init(halfWidth: CGFloat, halfHeight: CGFloat) {
        self.halfWidth = halfWidth
        self.halfHeight = halfHeight
    }

    init(_ profile: NavigationAgentProfile) {
        self.init(halfWidth: profile.halfWidth, halfHeight: profile.halfHeight)
    }

    var navigationProfile: NavigationAgentProfile {
        NavigationAgentProfile(halfWidth: halfWidth, halfHeight: halfHeight)
    }
}

// MARK: - The area record

/// One area, in the sense Baldur's Gate means it: a complete record of a place,
/// not a class that draws one.
///
/// The section list follows `.ARE` deliberately — entrances, regions, actors,
/// containers, doors, animations, ambients, automap notes, variables, one area
/// script — because that set is what makes areas uniform. Every area in the
/// Infinity Engine, interior or exterior, is this same record run by the same
/// code, which is why adding a location there is authoring rather than
/// programming.
///
/// Collections default to empty when a key is absent, so a small interior
/// authors a small file.
struct AreaDefinition: Hashable, Codable, Sendable {
    // Header
    var id: AreaID
    var displayName: String
    var kind: AreaKind
    /// Banner shown on arrival.
    var arrivalHint: String?
    /// Minimum corner of the area in world space. Zero for the districts, whose
    /// plates start at the origin; the office plate is centred on its layout
    /// focus instead, so its search-map frame does not begin at (0, 0).
    var worldOrigin: AreaPoint
    var worldSize: AreaSize
    /// The opaque pre-rendered background — the project's "area plate".
    var plateTextureName: String
    /// Crop shown in the HUD area map.
    var mapTextureName: String?
    /// Camera clamp, when it is tighter than the plate. The office plate is
    /// letterboxed with baked black margin, and a followed camera clamped to the
    /// plate rect would swing out over it; BG clamps to the painted area for the
    /// same reason. Omit to clamp to `worldBounds`.
    var cameraClampRect: AreaRect?

    // Navigation
    /// Indexed search-map bitmap resource. When absent, `obstacles` is
    /// rasterised instead, so an area can adopt the bitmap independently.
    var searchMapName: String?
    var obstacles: [AreaRect]
    var agentProfile: AreaAgentProfile

    // Sections
    var entrances: [AreaEntrance]
    var regions: [AreaRegion]
    var props: [AreaProp]
    var actors: [AreaActor]
    var containers: [AreaContainer]
    var doors: [AreaDoor]
    var notes: [AreaNote]
    var ambients: [AreaAmbient]

    /// Area-script identifier, run once per logic tick while the area is loaded.
    var script: String?

    init(
        id: AreaID,
        displayName: String,
        kind: AreaKind,
        arrivalHint: String? = nil,
        worldOrigin: AreaPoint = AreaPoint(x: 0, y: 0),
        worldSize: AreaSize,
        plateTextureName: String,
        mapTextureName: String? = nil,
        cameraClampRect: AreaRect? = nil,
        searchMapName: String? = nil,
        obstacles: [AreaRect] = [],
        agentProfile: AreaAgentProfile,
        entrances: [AreaEntrance] = [],
        regions: [AreaRegion] = [],
        props: [AreaProp] = [],
        actors: [AreaActor] = [],
        containers: [AreaContainer] = [],
        doors: [AreaDoor] = [],
        notes: [AreaNote] = [],
        ambients: [AreaAmbient] = [],
        script: String? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.kind = kind
        self.arrivalHint = arrivalHint
        self.worldOrigin = worldOrigin
        self.worldSize = worldSize
        self.plateTextureName = plateTextureName
        self.mapTextureName = mapTextureName
        self.cameraClampRect = cameraClampRect
        self.searchMapName = searchMapName
        self.obstacles = obstacles
        self.agentProfile = agentProfile
        self.entrances = entrances
        self.regions = regions
        self.props = props
        self.actors = actors
        self.containers = containers
        self.doors = doors
        self.notes = notes
        self.ambients = ambients
        self.script = script
    }

    // MARK: Derived

    var worldBounds: CGRect {
        CGRect(origin: worldOrigin.cgPoint, size: worldSize.cgSize)
    }

    /// Where a followed camera is allowed to go.
    var cameraClampBounds: CGRect {
        cameraClampRect?.cgRect ?? worldBounds
    }

    func entrance(named name: String?) -> AreaEntrance? {
        guard let name else { return entrance(named: AreaEntrance.defaultName) }
        return entrances.first { $0.name == name }
    }

    /// Arrival point for a transition, falling back to the default entrance and
    /// then to the first authored one. Never silently returns the origin: an
    /// area with no entrances is rejected at load.
    func spawnPoint(entrance name: String?) -> CGPoint? {
        (entrance(named: name)
            ?? entrance(named: AreaEntrance.defaultName)
            ?? entrances.first)?.point.cgPoint
    }

    func region(id: String) -> AreaRegion? {
        regions.first { $0.id == id }
    }

    var travelRegions: [AreaRegion] {
        regions.filter { $0.kind == .travel }
    }

    /// The region under a world point, topmost-authored first so a small region
    /// layered over a large one wins.
    func region(at point: CGPoint, of kind: AreaRegionKind? = nil) -> AreaRegion? {
        regions.last { region in
            (kind == nil || region.kind == kind) && region.contains(point)
        }
    }

    /// Build the runtime navigation map from the authored obstacles.
    ///
    /// Doors are handed over separately so `NavigationMap` can stamp and clear
    /// them in place rather than rebuilding, which is what lets a door open
    /// mid-walk without invalidating a route.
    func makeNavigationMap() -> NavigationMap {
        NavigationMap(
            worldBounds: worldBounds,
            obstacles: obstacles.map(\.cgRect),
            agentProfile: agentProfile.navigationProfile,
            doorObstacles: doors.map(\.closedObstacle.cgRect),
            entranceDoorBlocking: doors.contains { $0.startsClosed }
        )
    }

    // MARK: Codable

    private enum CodingKeys: String, CodingKey {
        case id, displayName, kind, arrivalHint, worldOrigin, worldSize
        case plateTextureName, mapTextureName, cameraClampRect
        case searchMapName, obstacles, agentProfile
        case entrances, regions, props, actors, containers, doors, notes, ambients
        case script
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(AreaID.self, forKey: .id)
        displayName = try container.decode(String.self, forKey: .displayName)
        kind = try container.decode(AreaKind.self, forKey: .kind)
        arrivalHint = try container.decodeIfPresent(String.self, forKey: .arrivalHint)
        worldOrigin = try container.decodeIfPresent(AreaPoint.self, forKey: .worldOrigin)
            ?? AreaPoint(x: 0, y: 0)
        worldSize = try container.decode(AreaSize.self, forKey: .worldSize)
        plateTextureName = try container.decode(String.self, forKey: .plateTextureName)
        mapTextureName = try container.decodeIfPresent(String.self, forKey: .mapTextureName)
        cameraClampRect = try container.decodeIfPresent(AreaRect.self, forKey: .cameraClampRect)
        searchMapName = try container.decodeIfPresent(String.self, forKey: .searchMapName)
        obstacles = try container.decodeIfPresent([AreaRect].self, forKey: .obstacles) ?? []
        agentProfile = try container.decode(AreaAgentProfile.self, forKey: .agentProfile)
        entrances = try container.decodeIfPresent([AreaEntrance].self, forKey: .entrances) ?? []
        regions = try container.decodeIfPresent([AreaRegion].self, forKey: .regions) ?? []
        props = try container.decodeIfPresent([AreaProp].self, forKey: .props) ?? []
        actors = try container.decodeIfPresent([AreaActor].self, forKey: .actors) ?? []
        containers = try container.decodeIfPresent([AreaContainer].self, forKey: .containers) ?? []
        doors = try container.decodeIfPresent([AreaDoor].self, forKey: .doors) ?? []
        notes = try container.decodeIfPresent([AreaNote].self, forKey: .notes) ?? []
        ambients = try container.decodeIfPresent([AreaAmbient].self, forKey: .ambients) ?? []
        script = try container.decodeIfPresent(String.self, forKey: .script)
    }
}
