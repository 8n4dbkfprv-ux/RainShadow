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

/// Coarse interior/exterior split: weather, lighting preset, and whether the
/// world map can reach the area directly. `AreaType` carries the rest.
enum AreaKind: String, Codable, Sendable {
    case interior
    case exterior
}

/// The `.ARE` header's area-type bitfield (`AREATYPE.IDS`, offset 0x0048).
///
/// This is a set, not an alternative to `AreaKind`, because in the Infinity
/// Engine an area is several things at once: a city street is Outdoor **and**
/// City, and the engine branches on the combination. `Map::ExploreMapChunk`
/// shrouds beyond a closed door only when `AT_OUTDOOR && !AT_CITY` — a wilderness
/// road, never a ward — so a two-case enum cannot express the distinction the
/// fog rule actually keys on.
///
/// Bit values are the engine's own (GemRB `Map.h`): outdoor 1, city 8,
/// forest 0x10, dungeon 0x20, extended night 0x40, can-rest-indoors 0x80.
/// Bits 1, 2 are unused by the games we follow and are not modelled.
struct AreaType: OptionSet, Hashable, Sendable {
    var rawValue: UInt16

    init(rawValue: UInt16) { self.rawValue = rawValue }

    static let outdoor = AreaType(rawValue: 1 << 0)
    static let city = AreaType(rawValue: 1 << 3)
    static let forest = AreaType(rawValue: 1 << 4)
    static let dungeon = AreaType(rawValue: 1 << 5)
    /// The area authors a second night painting rather than tinting the day one.
    static let extendedNight = AreaType(rawValue: 1 << 6)
    static let canRestIndoors = AreaType(rawValue: 1 << 7)

    /// What the engine reads to decide whether a closed door shrouds what lies
    /// beyond it or simply blocks. Cities are excluded deliberately: GemRB's own
    /// comment is "exclude cities to avoid unnecessary shrouding".
    var shroudsBeyondClosedDoors: Bool {
        contains(.outdoor) && !contains(.city)
    }

    /// Sensible reading of an area that predates this field.
    init(defaultingFor kind: AreaKind) {
        self = kind == .exterior ? .outdoor : []
    }
}

extension AreaType: Codable {
    /// Encoded as sorted names rather than a packed word. The engine stores a
    /// bitfield because it was counting bytes; a shipped record that a person
    /// reviews in a diff is better off saying `["city","outdoor"]`.
    private static let names: [(AreaType, String)] = [
        (.outdoor, "outdoor"), (.city, "city"), (.forest, "forest"),
        (.dungeon, "dungeon"), (.extendedNight, "extendedNight"),
        (.canRestIndoors, "canRestIndoors")
    ]

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode([String].self)
        var value: AreaType = []
        for name in raw {
            guard let match = Self.names.first(where: { $0.1 == name }) else {
                throw DecodingError.dataCorrupted(
                    .init(codingPath: decoder.codingPath, debugDescription: "Unknown area type \(name)")
                )
            }
            value.insert(match.0)
        }
        self = value
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(Self.names.filter { contains($0.0) }.map(\.1).sorted())
    }
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

/// 24-bit hour schedule, matching the Infinity Engine actor/ambient/animation
/// mask. Bit *n* covers the hour that starts at `n:30` (bit 0 is 00:30–01:29),
/// which is how the engine itself offsets the clock.
///
/// RainShadow is night-pinned, so authored content uses `night` or `always`.
/// A day-only mask is legal in the file and stays inert until a clock exists
/// that can sit in those hours.
struct HourSchedule: Hashable, Codable, Sendable, RawRepresentable {
    /// Lower 24 bits only; the engine has no 25th hour.
    var rawValue: UInt32

    init(rawValue: UInt32) {
        self.rawValue = rawValue & 0x00FF_FFFF
    }

    /// Every hour. Existing looping beds and always-on animations use this.
    static let always = HourSchedule(rawValue: 0x00FF_FFFF)
    /// 20:00–05:59, the night band this game actually plays.
    static let night = HourSchedule(rawValue: 0x00F0_003F)

    func isActive(atHour hour: Int) -> Bool {
        let wrapped = ((hour % 24) + 24) % 24
        return (rawValue & (1 << wrapped)) != 0
    }

    /// Engine evaluation: add the 30-minute offset, then test the hour bit.
    func isActive(atSecondsAfterMidnight seconds: Int) -> Bool {
        let shiftedHour = (seconds + 30 * 60) / 3600
        return isActive(atHour: shiftedHour)
    }
}

/// Mouse cursor an info/travel/trigger region should show, matching the small
/// set of ARE cursor kinds RainShadow actually uses. `nil` on a region means
/// "derive from `kind`".
enum AreaCursorKind: String, Codable, Sendable {
    case arrow
    case info
    case travel
    case door
    case hidden
}

/// Search-map cell as area data. Door impeded-cell lists in an `.ARE` are this:
/// integer column/row pairs on the 16×12 grid, not world points.
struct AreaSearchCell: Hashable, Codable, Sendable {
    var column: Int
    var row: Int

    init(column: Int, row: Int) {
        self.column = column
        self.row = row
    }

    init(_ cell: SearchMapCell) {
        self.init(column: cell.column, row: cell.row)
    }

    var searchMapCell: SearchMapCell {
        SearchMapCell(column: column, row: row)
    }
}

/// How a positional ambient picks the next sound from its pool.
enum AreaAmbientSelection: String, Codable, Sendable {
    case sequential
    case random
}

/// Day / night / battle music slots from the `.ARE` song entries. Battle is
/// reserved: RainShadow has no combat music yet, but the slot exists so an
/// area file does not have to grow a schema version to gain one.
struct AreaSongs: Hashable, Codable, Sendable {
    var day: String?
    var night: String?
    var battle: String?

    init(day: String? = nil, night: String? = nil, battle: String? = nil) {
        self.day = day
        self.night = night
        self.battle = battle
    }

    var isEmpty: Bool { day == nil && night == nil && battle == nil }
}

/// A looping (or chance-looping) sprite animation placed on the plate — neon,
/// steam, a ceiling-fan shadow, water shimmer. The ARE animation list, not a
/// WED overlay; RainShadow has no tileset, so an animated strip on a rect is
/// the equivalent.
struct AreaAnimation: Hashable, Codable, Sendable {
    var id: String
    var point: AreaPoint
    var textureName: String
    var atlasName: String?
    var frameCount: Int
    var frameRate: CGFloat
    /// 0...1. `1` always loops; `0` plays once.
    var loopChance: CGFloat
    var randomStartFrame: Bool
    var alpha: CGFloat
    /// Skip lightmap tint — neon, lamps, anything that is itself the light.
    var isSelfIlluminated: Bool
    /// ARE "wall hides" / WED "cover animations": disappear behind wall polygons.
    var wallHides: Bool
    var schedule: HourSchedule
    var blend: AreaPropBlend
    var scale: CGFloat
    var anchorX: CGFloat
    var anchorY: CGFloat

    init(
        id: String,
        point: AreaPoint,
        textureName: String,
        atlasName: String? = nil,
        frameCount: Int = 1,
        frameRate: CGFloat = 8,
        loopChance: CGFloat = 1,
        randomStartFrame: Bool = false,
        alpha: CGFloat = 1,
        isSelfIlluminated: Bool = false,
        wallHides: Bool = false,
        schedule: HourSchedule = .always,
        blend: AreaPropBlend = .alpha,
        scale: CGFloat = 1,
        anchorX: CGFloat = 0.5,
        anchorY: CGFloat = 0.5
    ) {
        self.id = id
        self.point = point
        self.textureName = textureName
        self.atlasName = atlasName
        self.frameCount = frameCount
        self.frameRate = frameRate
        self.loopChance = loopChance
        self.randomStartFrame = randomStartFrame
        self.alpha = alpha
        self.isSelfIlluminated = isSelfIlluminated
        self.wallHides = wallHides
        self.schedule = schedule
        self.blend = blend
        self.scale = scale
        self.anchorX = anchorX
        self.anchorY = anchorY
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        point = try c.decode(AreaPoint.self, forKey: .point)
        textureName = try c.decode(String.self, forKey: .textureName)
        atlasName = try c.decodeIfPresent(String.self, forKey: .atlasName)
        frameCount = try c.decodeIfPresent(Int.self, forKey: .frameCount) ?? 1
        frameRate = try c.decodeIfPresent(CGFloat.self, forKey: .frameRate) ?? 8
        loopChance = try c.decodeIfPresent(CGFloat.self, forKey: .loopChance) ?? 1
        randomStartFrame = try c.decodeIfPresent(Bool.self, forKey: .randomStartFrame) ?? false
        alpha = try c.decodeIfPresent(CGFloat.self, forKey: .alpha) ?? 1
        isSelfIlluminated = try c.decodeIfPresent(Bool.self, forKey: .isSelfIlluminated) ?? false
        wallHides = try c.decodeIfPresent(Bool.self, forKey: .wallHides) ?? false
        schedule = try c.decodeIfPresent(HourSchedule.self, forKey: .schedule) ?? .always
        blend = try c.decodeIfPresent(AreaPropBlend.self, forKey: .blend) ?? .alpha
        scale = try c.decodeIfPresent(CGFloat.self, forKey: .scale) ?? 1
        anchorX = try c.decodeIfPresent(CGFloat.self, forKey: .anchorX) ?? 0.5
        anchorY = try c.decodeIfPresent(CGFloat.self, forKey: .anchorY) ?? 0.5
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
    /// ARE region flags. Defaults match an ordinary info point: detectable,
    /// active, not party-gated, no reset.
    var isDetectable: Bool
    var isDeactivated: Bool
    var partyOnly: Bool
    var resets: Bool
    var cursor: AreaCursorKind?

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
        lockedLine: String? = nil,
        isDetectable: Bool = true,
        isDeactivated: Bool = false,
        partyOnly: Bool = false,
        resets: Bool = false,
        cursor: AreaCursorKind? = nil
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
        self.isDetectable = isDetectable
        self.isDeactivated = isDeactivated
        self.partyOnly = partyOnly
        self.resets = resets
        self.cursor = cursor
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
        lockedLine: String? = nil,
        isDetectable: Bool = true,
        isDeactivated: Bool = false,
        partyOnly: Bool = false,
        resets: Bool = false,
        cursor: AreaCursorKind? = nil
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
            lockedLine: lockedLine,
            isDetectable: isDetectable,
            isDeactivated: isDeactivated,
            partyOnly: partyOnly,
            resets: resets,
            cursor: cursor
        )
    }

    var boundingBox: CGRect { polygon.outlineBoundingBox }

    func contains(_ point: CGPoint) -> Bool { polygon.outlineContains(point) }

    /// Cursor shown when the pointer is over this region. Authored `cursor`
    /// wins; otherwise the kind picks the IE default.
    var resolvedCursor: AreaCursorKind {
        if let cursor { return cursor }
        switch kind {
        case .info: return .info
        case .travel: return .travel
        case .trigger: return .arrow
        }
    }

    private enum CodingKeys: String, CodingKey {
        case id, kind, label, polygon, approachPoint, travel
        case observation, scriptBlock, requiresFlag, lockedLine
        case isDetectable, isDeactivated, partyOnly, resets, cursor
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        kind = try c.decode(AreaRegionKind.self, forKey: .kind)
        label = try c.decodeIfPresent(String.self, forKey: .label)
        polygon = try c.decode([AreaPoint].self, forKey: .polygon)
        approachPoint = try c.decodeIfPresent(AreaPoint.self, forKey: .approachPoint)
        travel = try c.decodeIfPresent(AreaTravel.self, forKey: .travel)
        observation = try c.decodeIfPresent(String.self, forKey: .observation)
        scriptBlock = try c.decodeIfPresent(String.self, forKey: .scriptBlock)
        requiresFlag = try c.decodeIfPresent(String.self, forKey: .requiresFlag)
        lockedLine = try c.decodeIfPresent(String.self, forKey: .lockedLine)
        isDetectable = try c.decodeIfPresent(Bool.self, forKey: .isDetectable) ?? true
        isDeactivated = try c.decodeIfPresent(Bool.self, forKey: .isDeactivated) ?? false
        partyOnly = try c.decodeIfPresent(Bool.self, forKey: .partyOnly) ?? false
        resets = try c.decodeIfPresent(Bool.self, forKey: .resets) ?? false
        cursor = try c.decodeIfPresent(AreaCursorKind.self, forKey: .cursor)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(kind, forKey: .kind)
        try c.encodeIfPresent(label, forKey: .label)
        try c.encode(polygon, forKey: .polygon)
        try c.encodeIfPresent(approachPoint, forKey: .approachPoint)
        try c.encodeIfPresent(travel, forKey: .travel)
        try c.encodeIfPresent(observation, forKey: .observation)
        try c.encodeIfPresent(scriptBlock, forKey: .scriptBlock)
        try c.encodeIfPresent(requiresFlag, forKey: .requiresFlag)
        try c.encodeIfPresent(lockedLine, forKey: .lockedLine)
        if !isDetectable { try c.encode(isDetectable, forKey: .isDetectable) }
        if isDeactivated { try c.encode(isDeactivated, forKey: .isDeactivated) }
        if partyOnly { try c.encode(partyOnly, forKey: .partyOnly) }
        if resets { try c.encode(resets, forKey: .resets) }
        try c.encodeIfPresent(cursor, forKey: .cursor)
    }
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
    /// `WF_DITHER` (WED flag bit 1, value 2): "the polygon only dithers what it
    /// covers". This is the flag `Map::DrawStencil` reads to pick the stencil's
    /// red channel — `0x80` when set, `0xFF` when not — so a wall without it
    /// hides an actor outright where one with it shows them through.
    var dithers: Bool
    /// How far camera-up of the outline an actor is still covered, in world
    /// units. `0` means "the whole sprite" — current behaviour, and the right
    /// default for a wall whose height is the painted facade itself.
    var height: CGFloat

    init(
        id: String,
        polygon: [AreaPoint],
        coversActors: Bool = true,
        shadesBothSides: Bool = false,
        dithers: Bool = true,
        height: CGFloat = 0
    ) {
        self.id = id
        self.polygon = polygon
        self.coversActors = coversActors
        self.shadesBothSides = shadesBothSides
        self.dithers = dithers
        self.height = height
    }

    init(
        id: String,
        rect: CGRect,
        coversActors: Bool = true,
        shadesBothSides: Bool = false,
        dithers: Bool = true,
        height: CGFloat = 0
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
            shadesBothSides: shadesBothSides,
            dithers: dithers,
            height: height
        )
    }

    var boundingBox: CGRect { polygon.outlineBoundingBox }

    func contains(_ point: CGPoint) -> Bool { polygon.outlineContains(point) }

    /// WED cover test: feet inside the outline, and the wall is tall enough to
    /// hide this body. `height == 0` means "the painted facade itself", which
    /// covers any actor who stands in it.
    func coversActor(at point: CGPoint, height actorHeight: CGFloat) -> Bool {
        guard coversActors, contains(point) else { return false }
        if height <= 0 { return true }
        return height >= actorHeight * 0.4
    }

    private enum CodingKeys: String, CodingKey {
        case id, polygon, coversActors, shadesBothSides, dithers, height
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        polygon = try c.decode([AreaPoint].self, forKey: .polygon)
        coversActors = try c.decodeIfPresent(Bool.self, forKey: .coversActors) ?? true
        shadesBothSides = try c.decodeIfPresent(Bool.self, forKey: .shadesBothSides) ?? false
        // Defaults true so every authored area keeps the presentation it shipped
        // with: RainShadow's covering polygons have always shown the actor
        // through, which is `WF_DITHER`. A wall that should hide outright has to
        // say so.
        dithers = try c.decodeIfPresent(Bool.self, forKey: .dithers) ?? true
        height = try c.decodeIfPresent(CGFloat.self, forKey: .height) ?? 0
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(polygon, forKey: .polygon)
        try c.encode(coversActors, forKey: .coversActors)
        try c.encode(shadesBothSides, forKey: .shadesBothSides)
        if !dithers { try c.encode(dithers, forKey: .dithers) }
        if height != 0 { try c.encode(height, forKey: .height) }
    }
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
    var schedule: HourSchedule

    init(
        id: String,
        kind: String,
        point: AreaPoint,
        facing: CGFloat? = nil,
        requiresFlag: String? = nil,
        schedule: HourSchedule = .always
    ) {
        self.id = id
        self.kind = kind
        self.point = point
        self.facing = facing
        self.requiresFlag = requiresFlag
        self.schedule = schedule
    }

    private enum CodingKeys: String, CodingKey {
        case id, kind, point, facing, requiresFlag, schedule
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        kind = try c.decode(String.self, forKey: .kind)
        point = try c.decode(AreaPoint.self, forKey: .point)
        facing = try c.decodeIfPresent(CGFloat.self, forKey: .facing)
        requiresFlag = try c.decodeIfPresent(String.self, forKey: .requiresFlag)
        schedule = try c.decodeIfPresent(HourSchedule.self, forKey: .schedule) ?? .always
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(kind, forKey: .kind)
        try c.encode(point, forKey: .point)
        try c.encodeIfPresent(facing, forKey: .facing)
        try c.encodeIfPresent(requiresFlag, forKey: .requiresFlag)
        if schedule != .always { try c.encode(schedule, forKey: .schedule) }
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
///
/// When `closedIsBakedIntoPlate` is true (IE outdoor primary tiles), the closed
/// leaf lives in the background plate; the runtime sprite is only the open
/// secondary tiles and stays hidden while the door is shut.
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
    /// Closed art is already in the area plate (WED primary tiles).
    var closedIsBakedIntoPlate: Bool

    init(
        position: AreaPoint,
        canvasAnchor: AreaPoint,
        scale: CGFloat,
        closedTextureName: String,
        midTextureName: String,
        openTextureName: String,
        closedHoverTextureName: String? = nil,
        midHoverTextureName: String? = nil,
        openHoverTextureName: String? = nil,
        closedIsBakedIntoPlate: Bool = false
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
        self.closedIsBakedIntoPlate = closedIsBakedIntoPlate
    }

    private enum CodingKeys: String, CodingKey {
        case position, canvasAnchor, scale
        case closedTextureName, midTextureName, openTextureName
        case closedHoverTextureName, midHoverTextureName, openHoverTextureName
        case closedIsBakedIntoPlate
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        position = try c.decode(AreaPoint.self, forKey: .position)
        canvasAnchor = try c.decode(AreaPoint.self, forKey: .canvasAnchor)
        scale = try c.decode(CGFloat.self, forKey: .scale)
        closedTextureName = try c.decode(String.self, forKey: .closedTextureName)
        midTextureName = try c.decode(String.self, forKey: .midTextureName)
        openTextureName = try c.decode(String.self, forKey: .openTextureName)
        closedHoverTextureName = try c.decodeIfPresent(String.self, forKey: .closedHoverTextureName)
        midHoverTextureName = try c.decodeIfPresent(String.self, forKey: .midHoverTextureName)
        openHoverTextureName = try c.decodeIfPresent(String.self, forKey: .openHoverTextureName)
        closedIsBakedIntoPlate = try c.decodeIfPresent(Bool.self, forKey: .closedIsBakedIntoPlate) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(position, forKey: .position)
        try c.encode(canvasAnchor, forKey: .canvasAnchor)
        try c.encode(scale, forKey: .scale)
        try c.encode(closedTextureName, forKey: .closedTextureName)
        try c.encode(midTextureName, forKey: .midTextureName)
        try c.encode(openTextureName, forKey: .openTextureName)
        try c.encodeIfPresent(closedHoverTextureName, forKey: .closedHoverTextureName)
        try c.encodeIfPresent(midHoverTextureName, forKey: .midHoverTextureName)
        try c.encodeIfPresent(openHoverTextureName, forKey: .openHoverTextureName)
        if closedIsBakedIntoPlate {
            try c.encode(closedIsBakedIntoPlate, forKey: .closedIsBakedIntoPlate)
        }
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
    /// Whether the shut leaf stops sight as well as feet.
    ///
    /// The Infinity Engine spends door flag bit 9 on this — "Don't block line of
    /// sight" — so a door blocks it unless the area says otherwise. Kept the same
    /// way round as the engine's *behaviour* rather than its bit, so a door that
    /// says nothing behaves like every door in Baldur's Gate. Set it false for a
    /// grille, a beaded curtain, or a gate you are meant to see through.
    var blocksSight: Bool
    var isLocked: Bool
    var cannotClose: Bool
    var isSecret: Bool
    /// Secret door that has already been found. Unused in M01; the flag exists
    /// so a later area can author one without a schema bump.
    var isFound: Bool
    var keyItem: String?
    var lockedLine: String?
    var openSound: String?
    var closeSound: String?
    /// Two walk-to points on the walkable side; the player takes the nearer.
    /// Empty means "use the region's approach", which is what shipped doors do.
    var approachPoints: [AreaPoint]
    var closedOutline: [AreaPoint]
    var openOutline: [AreaPoint]
    var closedImpededCells: [AreaSearchCell]
    var openImpededCells: [AreaSearchCell]
    /// Upright painted opening, threshold to lintel, in world units. The Infinity
    /// Engine stores the door polygon off the paint; this is that height so a
    /// plate cannot ship a monumental arch against a 70.3-unit adult.
    var paintedApertureHeight: CGFloat?
    /// World-space box of the painted opening (not the search-map stamp).
    var paintedAperture: AreaRect?

    init(
        id: String,
        textureName: String? = nil,
        visual: AreaDoorVisualRegistration? = nil,
        closedObstacle: AreaRect,
        openObstacle: AreaRect? = nil,
        startsClosed: Bool = true,
        blocksSight: Bool = true,
        isLocked: Bool = false,
        cannotClose: Bool = false,
        isSecret: Bool = false,
        isFound: Bool = false,
        keyItem: String? = nil,
        lockedLine: String? = nil,
        openSound: String? = nil,
        closeSound: String? = nil,
        approachPoints: [AreaPoint] = [],
        closedOutline: [AreaPoint] = [],
        openOutline: [AreaPoint] = [],
        closedImpededCells: [AreaSearchCell] = [],
        openImpededCells: [AreaSearchCell] = [],
        paintedApertureHeight: CGFloat? = nil,
        paintedAperture: AreaRect? = nil
    ) {
        self.id = id
        self.textureName = textureName
        self.visual = visual
        self.closedObstacle = closedObstacle
        self.openObstacle = openObstacle
        self.startsClosed = startsClosed
        self.blocksSight = blocksSight
        self.isLocked = isLocked
        self.cannotClose = cannotClose
        self.isSecret = isSecret
        self.isFound = isFound
        self.keyItem = keyItem
        self.lockedLine = lockedLine
        self.openSound = openSound
        self.closeSound = closeSound
        self.approachPoints = approachPoints
        self.closedOutline = closedOutline
        self.openOutline = openOutline
        self.closedImpededCells = closedImpededCells
        self.openImpededCells = openImpededCells
        self.paintedApertureHeight = paintedApertureHeight
        self.paintedAperture = paintedAperture
    }

    private enum CodingKeys: String, CodingKey {
        case id, textureName, visual, closedObstacle, openObstacle
        case startsClosed, blocksSight, isLocked, cannotClose, isSecret, isFound
        case keyItem, lockedLine, openSound, closeSound, approachPoints
        case closedOutline, openOutline, closedImpededCells, openImpededCells
        case paintedApertureHeight, paintedAperture
    }

    /// Hand-written so `blocksSight` can be absent and mean the engine default.
    /// Every door authored before the flag existed blocked movement and, from
    /// this commit, blocks sight — which is what those doors were drawn as.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        textureName = try c.decodeIfPresent(String.self, forKey: .textureName)
        visual = try c.decodeIfPresent(AreaDoorVisualRegistration.self, forKey: .visual)
        closedObstacle = try c.decode(AreaRect.self, forKey: .closedObstacle)
        openObstacle = try c.decodeIfPresent(AreaRect.self, forKey: .openObstacle)
        startsClosed = try c.decodeIfPresent(Bool.self, forKey: .startsClosed) ?? true
        blocksSight = try c.decodeIfPresent(Bool.self, forKey: .blocksSight) ?? true
        isLocked = try c.decodeIfPresent(Bool.self, forKey: .isLocked) ?? false
        cannotClose = try c.decodeIfPresent(Bool.self, forKey: .cannotClose) ?? false
        isSecret = try c.decodeIfPresent(Bool.self, forKey: .isSecret) ?? false
        isFound = try c.decodeIfPresent(Bool.self, forKey: .isFound) ?? false
        keyItem = try c.decodeIfPresent(String.self, forKey: .keyItem)
        lockedLine = try c.decodeIfPresent(String.self, forKey: .lockedLine)
        openSound = try c.decodeIfPresent(String.self, forKey: .openSound)
        closeSound = try c.decodeIfPresent(String.self, forKey: .closeSound)
        approachPoints = try c.decodeIfPresent([AreaPoint].self, forKey: .approachPoints) ?? []
        closedOutline = try c.decodeIfPresent([AreaPoint].self, forKey: .closedOutline) ?? []
        openOutline = try c.decodeIfPresent([AreaPoint].self, forKey: .openOutline) ?? []
        closedImpededCells = try c.decodeIfPresent(
            [AreaSearchCell].self, forKey: .closedImpededCells
        ) ?? []
        openImpededCells = try c.decodeIfPresent(
            [AreaSearchCell].self, forKey: .openImpededCells
        ) ?? []
        paintedApertureHeight = try c.decodeIfPresent(CGFloat.self, forKey: .paintedApertureHeight)
        paintedAperture = try c.decodeIfPresent(AreaRect.self, forKey: .paintedAperture)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encodeIfPresent(textureName, forKey: .textureName)
        try c.encodeIfPresent(visual, forKey: .visual)
        try c.encode(closedObstacle, forKey: .closedObstacle)
        try c.encodeIfPresent(openObstacle, forKey: .openObstacle)
        try c.encode(startsClosed, forKey: .startsClosed)
        try c.encode(blocksSight, forKey: .blocksSight)
        if isLocked { try c.encode(isLocked, forKey: .isLocked) }
        if cannotClose { try c.encode(cannotClose, forKey: .cannotClose) }
        if isSecret { try c.encode(isSecret, forKey: .isSecret) }
        if isFound { try c.encode(isFound, forKey: .isFound) }
        try c.encodeIfPresent(keyItem, forKey: .keyItem)
        try c.encodeIfPresent(lockedLine, forKey: .lockedLine)
        try c.encodeIfPresent(openSound, forKey: .openSound)
        try c.encodeIfPresent(closeSound, forKey: .closeSound)
        if !approachPoints.isEmpty { try c.encode(approachPoints, forKey: .approachPoints) }
        if !closedOutline.isEmpty { try c.encode(closedOutline, forKey: .closedOutline) }
        if !openOutline.isEmpty { try c.encode(openOutline, forKey: .openOutline) }
        if !closedImpededCells.isEmpty {
            try c.encode(closedImpededCells, forKey: .closedImpededCells)
        }
        if !openImpededCells.isEmpty {
            try c.encode(openImpededCells, forKey: .openImpededCells)
        }
        try c.encodeIfPresent(paintedApertureHeight, forKey: .paintedApertureHeight)
        try c.encodeIfPresent(paintedAperture, forKey: .paintedAperture)
    }

    /// The leaf as the search map registers it, so the flag travels with the rect.
    var searchMapObstacle: DoorObstacle {
        DoorObstacle(
            id: id,
            closedRect: closedObstacle.cgRect,
            openRect: openObstacle?.cgRect,
            blocksSight: blocksSight,
            closedCells: closedImpededCells.map(\.searchMapCell),
            openCells: openImpededCells.map(\.searchMapCell),
            isOpen: !startsClosed
        )
    }

    /// Whether this door will open for a party carrying `keyItem`, if any.
    func canOpen(holdingKey: (String) -> Bool) -> Bool {
        if isSecret && !isFound { return false }
        guard isLocked else { return true }
        guard let keyItem else { return false }
        return holdingKey(keyItem)
    }

    /// Walk-to point: nearer of the authored pair, else the supplied fallback.
    func walkTarget(from point: CGPoint, fallback: CGPoint) -> CGPoint {
        nearestApproach(to: point)?.cgPoint ?? fallback
    }

    /// IE walks the player to the nearer of the two approach points.
    func nearestApproach(to point: CGPoint) -> AreaPoint? {
        guard !approachPoints.isEmpty else { return nil }
        return approachPoints.min { a, b in
            let da = hypot(a.x - point.x, a.y - point.y)
            let db = hypot(b.x - point.x, b.y - point.y)
            return da < db
        }
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
    /// Extra sounds in the pool. Empty means the pool is just `assetName`.
    var sounds: [String]
    var selection: AreaAmbientSelection
    var point: AreaPoint?
    var radius: CGFloat?
    var volume: CGFloat
    var isLooping: Bool
    /// Seconds between one-shots. `nil` on a looping bed.
    var interval: CGFloat?
    var intervalDeviation: CGFloat?
    /// Area-wide bed (the rain). When omitted, a missing `point` means global.
    var isGlobal: Bool
    var schedule: HourSchedule

    init(
        id: String,
        assetName: String,
        sounds: [String] = [],
        selection: AreaAmbientSelection = .sequential,
        point: AreaPoint? = nil,
        radius: CGFloat? = nil,
        volume: CGFloat = 1,
        isLooping: Bool = true,
        interval: CGFloat? = nil,
        intervalDeviation: CGFloat? = nil,
        isGlobal: Bool? = nil,
        schedule: HourSchedule = .always
    ) {
        self.id = id
        self.assetName = assetName
        self.sounds = sounds
        self.selection = selection
        self.point = point
        self.radius = radius
        self.volume = volume
        self.isLooping = isLooping
        self.interval = interval
        self.intervalDeviation = intervalDeviation
        self.isGlobal = isGlobal ?? (point == nil)
        self.schedule = schedule
    }

    /// Sounds the runtime actually draws from.
    var soundPool: [String] {
        sounds.isEmpty ? [assetName] : sounds
    }

    private enum CodingKeys: String, CodingKey {
        case id, assetName, sounds, selection, point, radius, volume
        case isLooping, interval, intervalDeviation, isGlobal, schedule
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        assetName = try c.decode(String.self, forKey: .assetName)
        sounds = try c.decodeIfPresent([String].self, forKey: .sounds) ?? []
        selection = try c.decodeIfPresent(AreaAmbientSelection.self, forKey: .selection)
            ?? .sequential
        point = try c.decodeIfPresent(AreaPoint.self, forKey: .point)
        radius = try c.decodeIfPresent(CGFloat.self, forKey: .radius)
        volume = try c.decodeIfPresent(CGFloat.self, forKey: .volume) ?? 1
        isLooping = try c.decodeIfPresent(Bool.self, forKey: .isLooping) ?? true
        interval = try c.decodeIfPresent(CGFloat.self, forKey: .interval)
        intervalDeviation = try c.decodeIfPresent(CGFloat.self, forKey: .intervalDeviation)
        isGlobal = try c.decodeIfPresent(Bool.self, forKey: .isGlobal) ?? (point == nil)
        schedule = try c.decodeIfPresent(HourSchedule.self, forKey: .schedule) ?? .always
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(assetName, forKey: .assetName)
        if !sounds.isEmpty { try c.encode(sounds, forKey: .sounds) }
        if selection != .sequential { try c.encode(selection, forKey: .selection) }
        try c.encodeIfPresent(point, forKey: .point)
        try c.encodeIfPresent(radius, forKey: .radius)
        try c.encode(volume, forKey: .volume)
        try c.encode(isLooping, forKey: .isLooping)
        try c.encodeIfPresent(interval, forKey: .interval)
        try c.encodeIfPresent(intervalDeviation, forKey: .intervalDeviation)
        let inferredGlobal = point == nil
        if isGlobal != inferredGlobal { try c.encode(isGlobal, forKey: .isGlobal) }
        if schedule != .always { try c.encode(schedule, forKey: .schedule) }
    }
}

/// Pathfinding agent footprint, authored per area because the office's obstacle
/// art already includes floor-contact clearance and the street's does not.
/// Mirrors `NavigationAgentProfile`, which is not itself `Codable`.
struct AreaAgentProfile: Hashable, Codable, Sendable {
    var halfWidth: CGFloat
    var halfHeight: CGFloat

    /// Creature stat #262, in **32-px fog tiles**. Default 14, clamped 0…15,
    /// set to 2 by blindness. 14 tiles is 448 area pixels — the BG visual range
    /// the modding docs quote. It lives here because the agent profile is the
    /// nearest thing an area record has to a creature.
    ///
    /// The search map is 16×12, so fog of war walks
    /// `SearchMapExplore.searchRadius(visualRangeInFogTiles:)` search cells
    /// (2× this stat, plus an adult footprint, cap 30). JSON still stores this
    /// number, not the converted radius.
    var visualRangeInCells: Int

    /// Stat #262's own bounds. A range of 0 is blind, not "unlimited".
    static let visualRangeBounds = 0...15
    /// What a creature sees when nothing says otherwise.
    static let defaultVisualRangeInCells = 14

    /// Search-map cells `ExploreMapChunk` walks for this stat.
    var searchSightRadiusInCells: Int {
        SearchMapExplore.searchRadius(visualRangeInFogTiles: visualRangeInCells)
    }

    init(
        halfWidth: CGFloat,
        halfHeight: CGFloat,
        visualRangeInCells: Int = AreaAgentProfile.defaultVisualRangeInCells
    ) {
        self.halfWidth = halfWidth
        self.halfHeight = halfHeight
        self.visualRangeInCells = Self.clampVisualRange(visualRangeInCells)
    }

    init(_ profile: NavigationAgentProfile) {
        self.init(halfWidth: profile.halfWidth, halfHeight: profile.halfHeight)
    }

    /// Hand-written so an area authored before sight was a stat decodes to the
    /// engine default rather than to zero, which would be blind.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        halfWidth = try c.decode(CGFloat.self, forKey: .halfWidth)
        halfHeight = try c.decode(CGFloat.self, forKey: .halfHeight)
        visualRangeInCells = Self.clampVisualRange(
            try c.decodeIfPresent(Int.self, forKey: .visualRangeInCells)
                ?? Self.defaultVisualRangeInCells
        )
    }

    private static func clampVisualRange(_ range: Int) -> Int {
        min(max(range, visualRangeBounds.lowerBound), visualRangeBounds.upperBound)
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
/// containers, doors, animations, ambients, automap notes, variables, songs,
/// wall polygons, one area script — because that set is what makes areas
/// uniform. Light and height maps sit beside the search map the way `LM.BMP`
/// / `HT.BMP` sit beside `SR.BMP`. Every area in the Infinity Engine, interior
/// or exterior, is this same record run by the same code, which is why adding
/// a location there is authoring rather than programming.
///
/// Collections default to empty when a key is absent, so a small interior
/// authors a small file.
struct AreaDefinition: Hashable, Codable, Sendable {
    // Header
    var id: AreaID
    var displayName: String
    var kind: AreaKind
    /// The `.ARE` area-type bits. Defaults from `kind` for records authored
    /// before the field existed, so an old exterior still reads as outdoor.
    var areaType: AreaType
    /// Banner shown on arrival.
    var arrivalHint: String?
    /// Minimum corner of the area in world space. Zero for the districts, whose
    /// plates start at the origin; the office plate is centred on its layout
    /// focus instead, so its search-map frame does not begin at (0, 0).
    var worldOrigin: AreaPoint
    var worldSize: AreaSize
    /// The opaque pre-rendered background — the project's "area plate".
    var plateTextureName: String
    /// Infinity Engine Extended Night plate. When set, the scene can swap the
    /// background at dusk instead of multiplying the day plate blue. Omit for
    /// interiors and for exteriors that have not authored a night painting yet.
    var nightPlateTextureName: String?
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
    /// The subset of `obstacles` that stops feet but not sight.
    ///
    /// Baldur's Gate spends two of its sixteen terrain indices on this
    /// distinction — 0 blocks movement and sight, 8 blocks movement only — so a
    /// desk, a railing or a parapet occludes nothing while a wall does. Without
    /// it, sight-based fog is unusable indoors: every chair in the office casts a
    /// shadow to the far wall.
    ///
    /// Authored as a subset rather than as a terrain on each obstacle so the
    /// existing rect arrays stay exactly as they are; `AreaCatalogTests` asserts
    /// every entry here is also in `obstacles`, which is what keeps the two from
    /// drifting apart. The bake reads this to choose the painted index, and the
    /// AABB fallback reads it for the same reason.
    var sightPermeableObstacles: [AreaRect]
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
    var animations: [AreaAnimation]
    /// Authored starting variables for this area — the `.ARE` variables section.
    /// Runtime mutation lives in `AreaVariables`; this is what an area begins as.
    var variables: [String: AreaVariableValue]
    var songs: AreaSongs
    /// Night light map resource stem (`<id>.lm` when omitted). The file is
    /// optional until Phase 4 bakes one.
    var lightMapName: String?
    /// Height map resource stem (`<id>.ht` when omitted). Optional; opt-in per
    /// area, same as the engine's HT.BMP.
    var heightMapName: String?

    /// Area-script identifier, run once per logic tick while the area is loaded.
    var script: String?

    init(
        id: AreaID,
        displayName: String,
        kind: AreaKind,
        areaType: AreaType? = nil,
        arrivalHint: String? = nil,
        worldOrigin: AreaPoint = AreaPoint(x: 0, y: 0),
        worldSize: AreaSize,
        plateTextureName: String,
        nightPlateTextureName: String? = nil,
        mapTextureName: String? = nil,
        cameraClampRect: AreaRect? = nil,
        searchMapName: String? = nil,
        obstacles: [AreaRect] = [],
        sightPermeableObstacles: [AreaRect] = [],
        defaultTerrain: SearchMapTerrain = .stone,
        agentProfile: AreaAgentProfile,
        entrances: [AreaEntrance] = [],
        regions: [AreaRegion] = [],
        props: [AreaProp] = [],
        wallPolygons: [AreaWallPolygon] = [],
        actors: [AreaActor] = [],
        containers: [AreaContainer] = [],
        doors: [AreaDoor] = [],
        notes: [AreaNote] = [],
        ambients: [AreaAmbient] = [],
        animations: [AreaAnimation] = [],
        variables: [String: AreaVariableValue] = [:],
        songs: AreaSongs = AreaSongs(),
        lightMapName: String? = nil,
        heightMapName: String? = nil,
        script: String? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.kind = kind
        self.areaType = areaType ?? AreaType(defaultingFor: kind)
        self.arrivalHint = arrivalHint
        self.worldOrigin = worldOrigin
        self.worldSize = worldSize
        self.plateTextureName = plateTextureName
        self.nightPlateTextureName = nightPlateTextureName
        self.mapTextureName = mapTextureName
        self.cameraClampRect = cameraClampRect
        self.searchMapName = searchMapName
        self.obstacles = obstacles
        self.sightPermeableObstacles = sightPermeableObstacles
        self.defaultTerrain = defaultTerrain
        self.agentProfile = agentProfile
        self.entrances = entrances
        self.regions = regions
        self.props = props
        self.wallPolygons = wallPolygons
        self.actors = actors
        self.containers = containers
        self.doors = doors
        self.notes = notes
        self.ambients = ambients
        self.animations = animations
        self.variables = variables
        self.songs = songs
        self.lightMapName = lightMapName
        self.heightMapName = heightMapName
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
    /// and the search map already use. `actorHeight` is the rendered body so a
    /// low wall (a kerb, a safe) does not stipple a standing adult; a polygon
    /// with `height == 0` covers regardless, which is the WED default.
    func isCovered(
        _ point: CGPoint,
        actorHeight: CGFloat = OfficeInteriorScale.renderedStandingDetectiveBodyHeight
    ) -> Bool {
        wallPolygons.contains { $0.coversActor(at: point, height: actorHeight) }
    }

    /// Animations flagged `wallHides` disappear behind covering scenery.
    func hidesWallLockedAnimation(at point: CGPoint) -> Bool {
        isCovered(point)
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
                    sightPermeableObstacles: sightPermeableObstacles
                        .map(\.cgRect.standardized),
                    doorObstacles: doors.map(\.searchMapObstacle)
                ),
                agentProfile: agentProfile.navigationProfile,
                doorObstacles: doors.map(\.searchMapObstacle),
                entranceDoorBlocking: doors.contains { $0.startsClosed }
            )
        }
        return NavigationMap(
            worldBounds: worldBounds,
            obstacles: obstacles.map(\.cgRect),
            agentProfile: agentProfile.navigationProfile,
            doorObstacles: doors.map(\.searchMapObstacle),
            entranceDoorBlocking: doors.contains { $0.startsClosed },
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
        case id, displayName, kind, areaType, arrivalHint, worldOrigin, worldSize
        case plateTextureName, nightPlateTextureName, mapTextureName, cameraClampRect
        case searchMapName, obstacles, sightPermeableObstacles, defaultTerrain
        case agentProfile
        case entrances, regions, props, wallPolygons, actors, containers, doors, notes, ambients
        case animations, variables, songs, lightMapName, heightMapName
        case script
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(AreaID.self, forKey: .id)
        displayName = try container.decode(String.self, forKey: .displayName)
        kind = try container.decode(AreaKind.self, forKey: .kind)
        areaType = try container.decodeIfPresent(AreaType.self, forKey: .areaType)
            ?? AreaType(defaultingFor: kind)
        arrivalHint = try container.decodeIfPresent(String.self, forKey: .arrivalHint)
        worldOrigin = try container.decodeIfPresent(AreaPoint.self, forKey: .worldOrigin)
            ?? AreaPoint(x: 0, y: 0)
        worldSize = try container.decode(AreaSize.self, forKey: .worldSize)
        plateTextureName = try container.decode(String.self, forKey: .plateTextureName)
        nightPlateTextureName = try container.decodeIfPresent(
            String.self,
            forKey: .nightPlateTextureName
        )
        mapTextureName = try container.decodeIfPresent(String.self, forKey: .mapTextureName)
        cameraClampRect = try container.decodeIfPresent(AreaRect.self, forKey: .cameraClampRect)
        searchMapName = try container.decodeIfPresent(String.self, forKey: .searchMapName)
        obstacles = try container.decodeIfPresent([AreaRect].self, forKey: .obstacles) ?? []
        sightPermeableObstacles = try container.decodeIfPresent(
            [AreaRect].self,
            forKey: .sightPermeableObstacles
        ) ?? []
        defaultTerrain = try container.decodeIfPresent(
            SearchMapTerrain.self,
            forKey: .defaultTerrain
        ) ?? .stone
        agentProfile = try container.decode(AreaAgentProfile.self, forKey: .agentProfile)
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
        animations = try container.decodeIfPresent(
            [AreaAnimation].self, forKey: .animations
        ) ?? []
        variables = try container.decodeIfPresent(
            [String: AreaVariableValue].self, forKey: .variables
        ) ?? [:]
        songs = try container.decodeIfPresent(AreaSongs.self, forKey: .songs) ?? AreaSongs()
        lightMapName = try container.decodeIfPresent(String.self, forKey: .lightMapName)
        heightMapName = try container.decodeIfPresent(String.self, forKey: .heightMapName)
        script = try container.decodeIfPresent(String.self, forKey: .script)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(displayName, forKey: .displayName)
        try container.encode(kind, forKey: .kind)
        try container.encode(areaType, forKey: .areaType)
        try container.encodeIfPresent(arrivalHint, forKey: .arrivalHint)
        try container.encode(worldOrigin, forKey: .worldOrigin)
        try container.encode(worldSize, forKey: .worldSize)
        try container.encode(plateTextureName, forKey: .plateTextureName)
        try container.encodeIfPresent(nightPlateTextureName, forKey: .nightPlateTextureName)
        try container.encodeIfPresent(mapTextureName, forKey: .mapTextureName)
        try container.encodeIfPresent(cameraClampRect, forKey: .cameraClampRect)
        try container.encodeIfPresent(searchMapName, forKey: .searchMapName)
        try container.encode(obstacles, forKey: .obstacles)
        try container.encode(sightPermeableObstacles, forKey: .sightPermeableObstacles)
        try container.encode(defaultTerrain, forKey: .defaultTerrain)
        try container.encode(agentProfile, forKey: .agentProfile)
        try container.encode(entrances, forKey: .entrances)
        try container.encode(regions, forKey: .regions)
        try container.encode(props, forKey: .props)
        try container.encode(wallPolygons, forKey: .wallPolygons)
        try container.encode(actors, forKey: .actors)
        try container.encode(containers, forKey: .containers)
        try container.encode(doors, forKey: .doors)
        try container.encode(notes, forKey: .notes)
        try container.encode(ambients, forKey: .ambients)
        if !animations.isEmpty { try container.encode(animations, forKey: .animations) }
        if !variables.isEmpty { try container.encode(variables, forKey: .variables) }
        if !songs.isEmpty { try container.encode(songs, forKey: .songs) }
        try container.encodeIfPresent(lightMapName, forKey: .lightMapName)
        try container.encodeIfPresent(heightMapName, forKey: .heightMapName)
        try container.encodeIfPresent(script, forKey: .script)
    }

    /// Resource stem the night light map is loaded from. Authored name wins;
    /// otherwise `<id>.lm`, the IE `LM.BMP` analogue.
    var resolvedLightMapName: String { lightMapName ?? "\(id.rawValue).lm" }

    /// Resource stem the height map is loaded from. Authored name wins;
    /// otherwise `<id>.ht`.
    var resolvedHeightMapName: String { heightMapName ?? "\(id.rawValue).ht" }
}
