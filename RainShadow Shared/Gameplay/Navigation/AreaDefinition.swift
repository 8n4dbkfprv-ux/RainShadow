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

/// Outline maths shared by everything in an area that is a polygon.
///
/// Regions and wall polygons both are, and both are hit-tested constantly — a
/// region on every click, a wall on every actor move — so they use one
/// implementation rather than two that can drift.
extension Array where Element == AreaPoint {
    /// Axis-aligned bound, the cheap reject before the polygon test. BG stores
    /// this alongside the vertex range for the same reason.
    var outlineBoundingBox: CGRect {
        guard let first = self.first else { return .null }
        var minX = first.x, maxX = first.x
        var minY = first.y, maxY = first.y
        for vertex in dropFirst() {
            minX = Swift.min(minX, vertex.x)
            maxX = Swift.max(maxX, vertex.x)
            minY = Swift.min(minY, vertex.y)
            maxY = Swift.max(maxY, vertex.y)
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    /// Even-odd crossing test. The `>` comparison on both endpoints makes each
    /// edge half-open in y, so a horizontal ray through a shared vertex counts
    /// one crossing rather than two — a point on the boundary between two
    /// abutting outlines belongs to exactly one of them.
    func outlineContains(_ point: CGPoint) -> Bool {
        guard count >= 3, outlineBoundingBox.contains(point) else { return false }
        var isInside = false
        var j = count - 1
        for i in indices {
            let a = self[i]
            let b = self[j]
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

    var boundingBox: CGRect { polygon.outlineBoundingBox }

    func contains(_ point: CGPoint) -> Bool { polygon.outlineContains(point) }
}

/// A wall polygon: geometry that covers actors, carrying no art of its own.
///
/// Baldur's Gate does not draw scenery over a creature. Static scenery is
/// painted into the tileset, and the WED marks the parts of it that stand in
/// front of the floor with wall polygons whose flags say `Shade wall` and
/// `Cover animations`. When a creature walks behind one, the engine redraws the
/// wall over it and stipples the creature through — the familiar translucent
/// silhouette behind a building, rather than a sprite that vanishes.
///
/// That is why an `.ARE` has no props section: a desk is pixels in the tileset,
/// a wall polygon over those pixels, a search-map footprint, and a container
/// outline. Four records, no sprite. This is the third of them.
struct AreaWallPolygon: Hashable, Codable, Sendable {
    var id: String
    var polygon: [AreaPoint]
    /// WED flag bits 2–3. When set, an actor behind this outline is covered.
    var coversActors: Bool
    /// WED flag bit 0: shade animations from both sides of the wall.
    var shadesBothSides: Bool

    init(
        id: String,
        polygon: [AreaPoint],
        coversActors: Bool = true,
        shadesBothSides: Bool = false
    ) {
        self.id = id
        self.polygon = polygon
        self.coversActors = coversActors
        self.shadesBothSides = shadesBothSides
    }

    init(
        id: String,
        rect: CGRect,
        coversActors: Bool = true,
        shadesBothSides: Bool = false
    ) {
        let r = rect.standardized
        self.init(
            id: id,
            polygon: [
                AreaPoint(x: r.minX, y: r.minY),
                AreaPoint(x: r.maxX, y: r.minY),
                AreaPoint(x: r.maxX, y: r.maxY),
                AreaPoint(x: r.minX, y: r.maxY)
            ],
            coversActors: coversActors,
            shadesBothSides: shadesBothSides
        )
    }

    var boundingBox: CGRect { polygon.outlineBoundingBox }

    func contains(_ point: CGPoint) -> Bool { polygon.outlineContains(point) }
}

/// Which layer of the scene graph a prop is drawn into.
///
/// Not cosmetic: `depthWorld` sorts against actors by ground point, while
/// `rearFixtures` and `floorEffects` always draw beneath them. A wall picture
/// moved into the depth layer would start occluding the player.
enum AreaPropLayer: String, Codable, Sendable {
    /// Beneath everything — floor decals, light pools, contact shadows.
    case floorEffects
    /// Behind actors always — wall fixtures, window, radiator.
    case rearFixtures
    /// Depth-sorted against actors by ground point.
    case depthWorld
    /// Authored foreground, over actors unconditionally.
    case occlusion
}

/// How a prop composites. Five of the office's sprites are additive light casts;
/// drawing them as plain alpha washes the room out, which reads as a lighting
/// change rather than as a bug.
enum AreaPropBlend: String, Codable, Sendable {
    case alpha
    case add
    case multiply
    case screen
    case replace
}

/// A placed background object. Carries the depth-slicing fields
/// `CityDistrictScene.addDepthSlicedSprite` needs so a near-side facade can
/// occlude the far street while the player walks in front of it — RainShadow's
/// stand-in for the wall polygons a `.WED` would carry.
struct AreaProp: Hashable, Codable, Sendable {
    /// Node identity, which is *not* always the texture. The office rug is
    /// `office_worn_rug` and draws `office_worn_rug_burgundy`; hover
    /// registration and hotspot links key on this, art resolution on
    /// `textureName`. Conflating them composites the wrong picture.
    var id: String
    var textureName: String
    var layer: AreaPropLayer
    var groundPoint: AreaPoint
    /// Scale applied to the texture's natural size. Non-uniform because one
    /// prop is: the office window is drawn 0.35 wide by 0.32 tall.
    var scaleX: CGFloat
    var scaleY: CGFloat
    var anchorX: CGFloat
    var anchorY: CGFloat
    var depthBias: CGFloat
    /// Draw at an explicit world size instead of scaling the texture.
    ///
    /// The two are not interchangeable, and picking the wrong one is invisible
    /// until something animates the prop. `SKSpriteNode.size` and `xScale`
    /// *multiply*, so a sprite built at an absolute size has a scale of 1 — and
    /// the office's entrance leaf is driven by `setScale` on every fall and
    /// every restore, which would then render it at an eighth of itself. Prefer
    /// scale; reach for a size only where the art's own pixel dimensions are
    /// not the authoring unit, as in Sable Row's depth-sliced facades.
    var worldSize: AreaSize?
    var alpha: CGFloat
    var blend: AreaPropBlend
    /// Radians, counter-clockwise about the anchor.
    var rotation: CGFloat
    /// Corner displacement applied at draw time, in unit texture space.
    var warp: AreaPropWarp?
    /// Vertical strip width, in world units, for depth-sliced facades.
    var depthSliceWidth: CGFloat?
    /// Lot whose north kerb is the sort key for those strips.
    var depthSortLot: String?

    init(
        id: String? = nil,
        textureName: String,
        layer: AreaPropLayer = .depthWorld,
        groundPoint: AreaPoint,
        scale: CGFloat = 1,
        scaleX: CGFloat? = nil,
        scaleY: CGFloat? = nil,
        anchorX: CGFloat = 0.5,
        anchorY: CGFloat,
        depthBias: CGFloat = 0,
        worldSize: AreaSize? = nil,
        alpha: CGFloat = 1,
        blend: AreaPropBlend = .alpha,
        rotation: CGFloat = 0,
        warp: AreaPropWarp? = nil,
        depthSliceWidth: CGFloat? = nil,
        depthSortLot: String? = nil
    ) {
        self.id = id ?? textureName
        self.textureName = textureName
        self.layer = layer
        self.groundPoint = groundPoint
        self.scaleX = scaleX ?? scale
        self.scaleY = scaleY ?? scale
        self.anchorX = anchorX
        self.anchorY = anchorY
        self.depthBias = depthBias
        self.worldSize = worldSize
        self.alpha = alpha
        self.blend = blend
        self.rotation = rotation
        self.warp = warp
        self.depthSliceWidth = depthSliceWidth
        self.depthSortLot = depthSortLot
    }

    /// The uniform scale, when there is one. `nil` for a prop drawn stretched.
    var scale: CGFloat? { scaleX == scaleY ? scaleX : nil }

    private enum CodingKeys: String, CodingKey {
        case id, textureName, layer, groundPoint, scale, scaleX, scaleY
        case anchorX, anchorY
        case depthBias, worldSize, alpha, blend, rotation, warp
        case depthSliceWidth, depthSortLot
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        textureName = try c.decode(String.self, forKey: .textureName)
        id = try c.decodeIfPresent(String.self, forKey: .id) ?? textureName
        layer = try c.decodeIfPresent(AreaPropLayer.self, forKey: .layer) ?? .depthWorld
        groundPoint = try c.decode(AreaPoint.self, forKey: .groundPoint)
        // `scale` is the shorthand both axes fall back to, so the overwhelming
        // majority of props — every one drawn square — stay a single number in
        // the file rather than the same number written twice.
        let uniform = try c.decodeIfPresent(CGFloat.self, forKey: .scale) ?? 1
        scaleX = try c.decodeIfPresent(CGFloat.self, forKey: .scaleX) ?? uniform
        scaleY = try c.decodeIfPresent(CGFloat.self, forKey: .scaleY) ?? uniform
        anchorX = try c.decodeIfPresent(CGFloat.self, forKey: .anchorX) ?? 0.5
        anchorY = try c.decode(CGFloat.self, forKey: .anchorY)
        depthBias = try c.decodeIfPresent(CGFloat.self, forKey: .depthBias) ?? 0
        worldSize = try c.decodeIfPresent(AreaSize.self, forKey: .worldSize)
        alpha = try c.decodeIfPresent(CGFloat.self, forKey: .alpha) ?? 1
        blend = try c.decodeIfPresent(AreaPropBlend.self, forKey: .blend) ?? .alpha
        rotation = try c.decodeIfPresent(CGFloat.self, forKey: .rotation) ?? 0
        warp = try c.decodeIfPresent(AreaPropWarp.self, forKey: .warp)
        depthSliceWidth = try c.decodeIfPresent(CGFloat.self, forKey: .depthSliceWidth)
        depthSortLot = try c.decodeIfPresent(String.self, forKey: .depthSortLot)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(textureName, forKey: .textureName)
        try c.encode(layer, forKey: .layer)
        try c.encode(groundPoint, forKey: .groundPoint)
        if let scale {
            try c.encode(scale, forKey: .scale)
        } else {
            try c.encode(scaleX, forKey: .scaleX)
            try c.encode(scaleY, forKey: .scaleY)
        }
        try c.encode(anchorX, forKey: .anchorX)
        try c.encode(anchorY, forKey: .anchorY)
        try c.encode(depthBias, forKey: .depthBias)
        try c.encodeIfPresent(worldSize, forKey: .worldSize)
        try c.encode(alpha, forKey: .alpha)
        try c.encode(blend, forKey: .blend)
        try c.encode(rotation, forKey: .rotation)
        try c.encodeIfPresent(warp, forKey: .warp)
        try c.encodeIfPresent(depthSliceWidth, forKey: .depthSliceWidth)
        try c.encodeIfPresent(depthSortLot, forKey: .depthSortLot)
    }
}

/// A four-corner displacement applied to a prop as it is drawn, in unit texture
/// space with the origin bottom-left.
///
/// Not an Infinity Engine concept, and deliberately so. BG paints its
/// perspective into the tileset, so a window on a receding wall is simply drawn
/// receding. RainShadow's props are separate sprites over a painted plate, which
/// means a prop on a wall that leans has to be leaned to match — and rotating
/// the whole node instead tips the jambs and makes the window look pasted on.
///
/// One prop in the shipped rooms uses this. It is a field rather than a special
/// case in the office's code because a prop's geometry belongs in the prop's
/// record, and because the next painted wall will want it too.
struct AreaPropWarp: Hashable, Codable, Sendable {
    var bottomLeft: AreaPoint
    var bottomRight: AreaPoint
    var topLeft: AreaPoint
    var topRight: AreaPoint

    init(
        bottomLeft: AreaPoint,
        bottomRight: AreaPoint,
        topLeft: AreaPoint,
        topRight: AreaPoint
    ) {
        self.bottomLeft = bottomLeft
        self.bottomRight = bottomRight
        self.topLeft = topLeft
        self.topRight = topRight
    }

    /// The corners in SpriteKit's own order for a 1×1 destination grid: bottom
    /// row first, left to right.
    var destinationCorners: [AreaPoint] {
        [bottomLeft, bottomRight, topLeft, topRight]
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

/// Sprite registration for a door whose pixels are separate from its collision
/// footprint. All state canvases share one normalized anchor, world position
/// and scale, so changing state cannot move the hinge.
///
/// This is the same separation a WED door maintains between its visual tiles
/// and the ARE door that owns interaction/navigation state. It is optional so
/// older areas and doors whose visuals are baked into a facade keep decoding.
struct AreaDoorVisualRegistration: Hashable, Codable, Sendable {
    var position: AreaPoint
    var canvasAnchor: AreaPoint
    var scale: CGFloat
    var closedTextureName: String
    var midTextureName: String
    var openTextureName: String
    var closedHoverTextureName: String?
    var midHoverTextureName: String?
    var openHoverTextureName: String?

    init(
        position: AreaPoint,
        canvasAnchor: AreaPoint,
        scale: CGFloat,
        closedTextureName: String,
        midTextureName: String,
        openTextureName: String,
        closedHoverTextureName: String? = nil,
        midHoverTextureName: String? = nil,
        openHoverTextureName: String? = nil
    ) {
        self.position = position
        self.canvasAnchor = canvasAnchor
        self.scale = scale
        self.closedTextureName = closedTextureName
        self.midTextureName = midTextureName
        self.openTextureName = openTextureName
        self.closedHoverTextureName = closedHoverTextureName
        self.midHoverTextureName = midHoverTextureName
        self.openHoverTextureName = openHoverTextureName
    }
}

/// A door leaf that stamps and clears in place. `NavigationMap` already
/// supports this without rebuilding the search map; the area supplies the rects.
struct AreaDoor: Hashable, Codable, Sendable {
    var id: String
    /// Legacy single-texture hint. New registered doors use `visual`; retaining
    /// this field keeps existing area files source- and decode-compatible.
    var textureName: String?
    var visual: AreaDoorVisualRegistration?
    /// Blocking footprint while shut.
    var closedObstacle: AreaRect
    /// Blocking footprint while open; omit when an open door blocks nothing.
    var openObstacle: AreaRect?
    var startsClosed: Bool

    init(
        id: String,
        textureName: String? = nil,
        visual: AreaDoorVisualRegistration? = nil,
        closedObstacle: AreaRect,
        openObstacle: AreaRect? = nil,
        startsClosed: Bool = true
    ) {
        self.id = id
        self.textureName = textureName
        self.visual = visual
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
    /// Terrain written into open ground when no search map is painted. Decides
    /// what the area sounds like underfoot: the districts are paved, the office
    /// is boards.
    var defaultTerrain: SearchMapTerrain
    var agentProfile: AreaAgentProfile
    /// Node expansions a single path search may spend here.
    ///
    /// Area configuration, not engine configuration: the office runs 96,000
    /// against the 32,000 default because it is a small room packed with ~750
    /// obstacle rectangles, where a route threading furniture expands far more
    /// nodes per unit travelled than an open street does. Omit to take the
    /// engine default.
    var pathSearchBudget: Int?

    // Sections
    var entrances: [AreaEntrance]
    var regions: [AreaRegion]
    var props: [AreaProp]
    /// Scenery outlines that cover actors standing behind them.
    var wallPolygons: [AreaWallPolygon]
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
        defaultTerrain: SearchMapTerrain = .stone,
        agentProfile: AreaAgentProfile,
        pathSearchBudget: Int? = nil,
        entrances: [AreaEntrance] = [],
        regions: [AreaRegion] = [],
        props: [AreaProp] = [],
        wallPolygons: [AreaWallPolygon] = [],
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
        self.defaultTerrain = defaultTerrain
        self.agentProfile = agentProfile
        self.pathSearchBudget = pathSearchBudget
        self.entrances = entrances
        self.regions = regions
        self.props = props
        self.wallPolygons = wallPolygons
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

    /// Whether an actor standing here is behind scenery that should cover it.
    ///
    /// Asked of the actor's *ground point*, not its sprite bounds: a creature is
    /// behind a wall when its feet are, which is the same anchor depth sorting
    /// and the search map already use.
    func isCovered(_ point: CGPoint) -> Bool {
        wallPolygons.contains { $0.coversActors && $0.contains(point) }
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
    /// Door leaves, removed from the static set.
    ///
    /// A door's footprint is authored in `obstacles` as well, because it *is*
    /// solid while shut — but it has to be stamped separately or opening it
    /// would leave the static rasterisation still blocking the way. This is the
    /// same filter `NavigationMap`'s own initialiser applies; the painted-map
    /// path has to apply it too, or the office door opens onto a wall.
    private var staticObstaclesExcludingDoors: [CGRect] {
        let doorRects = doors.map(\.closedObstacle.cgRect.standardized)
        return obstacles.map(\.cgRect.standardized).filter { candidate in
            !doorRects.contains { door in
                abs(door.minX - candidate.minX) < 0.001
                    && abs(door.minY - candidate.minY) < 0.001
                    && abs(door.width - candidate.width) < 0.001
                    && abs(door.height - candidate.height) < 0.001
            }
        }
    }

    func makeNavigationMap() -> NavigationMap {
        if let searchMapName, let raster = try? AreaSearchMapLoader.load(named: searchMapName) {
            return NavigationMap(
                searchMap: SearchMap(
                    worldBounds: worldBounds,
                    terrainIndices: raster.terrainIndices,
                    columns: raster.columns,
                    rows: raster.rows,
                    obstacles: staticObstaclesExcludingDoors,
                    doorObstacles: doors.map(\.closedObstacle.cgRect)
                ),
                agentProfile: agentProfile.navigationProfile,
                doorObstacles: doors.map(\.closedObstacle.cgRect),
                entranceDoorBlocking: doors.contains { $0.startsClosed },
                maxNodes: pathSearchBudget ?? PathFinder.defaultMaxNodes
            )
        }
        return NavigationMap(
            worldBounds: worldBounds,
            obstacles: obstacles.map(\.cgRect),
            agentProfile: agentProfile.navigationProfile,
            doorObstacles: doors.map(\.closedObstacle.cgRect),
            entranceDoorBlocking: doors.contains { $0.startsClosed },
            maxNodes: pathSearchBudget ?? PathFinder.defaultMaxNodes,
            defaultTerrain: defaultTerrain
        )
    }

    /// Raster dimensions the area's search map must have, so a bake and the
    /// runtime cannot disagree about the grid.
    var searchMapGridSize: (columns: Int, rows: Int) {
        (
            columns: max(1, Int(ceil(worldSize.w / SearchMap.defaultCellSize.width))),
            rows: max(1, Int(ceil(worldSize.h / SearchMap.defaultCellSize.height)))
        )
    }

    // MARK: Codable

    private enum CodingKeys: String, CodingKey {
        case id, displayName, kind, arrivalHint, worldOrigin, worldSize
        case plateTextureName, mapTextureName, cameraClampRect
        case searchMapName, obstacles, defaultTerrain, agentProfile, pathSearchBudget
        case entrances, regions, props, wallPolygons, actors, containers, doors, notes, ambients
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
        defaultTerrain = try container.decodeIfPresent(
            SearchMapTerrain.self,
            forKey: .defaultTerrain
        ) ?? .stone
        agentProfile = try container.decode(AreaAgentProfile.self, forKey: .agentProfile)
        pathSearchBudget = try container.decodeIfPresent(Int.self, forKey: .pathSearchBudget)
        entrances = try container.decodeIfPresent([AreaEntrance].self, forKey: .entrances) ?? []
        regions = try container.decodeIfPresent([AreaRegion].self, forKey: .regions) ?? []
        props = try container.decodeIfPresent([AreaProp].self, forKey: .props) ?? []
        wallPolygons = try container.decodeIfPresent(
            [AreaWallPolygon].self,
            forKey: .wallPolygons
        ) ?? []
        actors = try container.decodeIfPresent([AreaActor].self, forKey: .actors) ?? []
        containers = try container.decodeIfPresent([AreaContainer].self, forKey: .containers) ?? []
        doors = try container.decodeIfPresent([AreaDoor].self, forKey: .doors) ?? []
        notes = try container.decodeIfPresent([AreaNote].self, forKey: .notes) ?? []
        ambients = try container.decodeIfPresent([AreaAmbient].self, forKey: .ambients) ?? []
        script = try container.decodeIfPresent(String.self, forKey: .script)
    }
}
