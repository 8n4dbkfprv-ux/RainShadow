import Foundation

/// Surface families a cell can sound like. Coarser than the terrain table
/// because RainShadow has baked two footstep sets, not seven; the mapping to
/// shipped audio lives in the app target beside `FootstepSurface`.
enum SearchMapSurface: String, CaseIterable, Sendable {
    /// Nothing walks here.
    case silent
    case wood
    case stone
    case sand
    case grass
    case water
}

/// Baldur's Gate's search-map terrain index.
///
/// An Infinity Engine area's `SR.BMP` stores one palette index per search cell,
/// and that single number answers five different questions: whether a creature
/// can walk there, whether line of sight passes, whether a flier can cross it,
/// whether a projectile can, and which footstep sample plays. RainShadow's
/// search map previously stored one bit — passable or not — so a wooden floor, a
/// wet cobble street and a stretch of harbour water were the same cell, and the
/// footstep sound had to be a per-scene constant instead of a property of the
/// ground.
///
/// The values are BG2's table verbatim, including its redundancies: 0 and 8 are
/// both obstacles differing only in whether sight passes, 3 and 9 are both
/// creaking wood, 6/11/12 are three waters of which only 12 is impassable, and
/// 1/15 differ in sound but not behaviour. Keeping the table as shipped means an
/// area authored against Infinity Engine documentation reads correctly here, and
/// means the gaps are BG's rather than ours.
enum SearchMapTerrain: UInt8, CaseIterable, Sendable {
    case obstacle = 0
    case sand = 1
    case wood = 2
    case woodCreaking = 3
    case stoneEchoey = 4
    case grass = 5
    case water = 6
    case stone = 7
    /// Blocks movement but not sight — a low wall, a railing, a parapet.
    case obstacleSeeThrough = 8
    case woodCreakingAlt = 9
    case wall = 10
    case waterShallow = 11
    /// Deep water: sight and projectiles cross it, feet do not.
    case waterImpassable = 12
    case roof = 13
    /// Not walkable; stepping onto the cell hands the player to the world map.
    case worldMapExit = 14
    case grassAlt = 15

    /// Whether a floor-bound creature can stand here.
    var isWalkable: Bool {
        switch self {
        case .obstacle, .obstacleSeeThrough, .wall, .waterImpassable, .roof, .worldMapExit:
            false
        case .sand, .wood, .woodCreaking, .stoneEchoey, .grass, .water, .stone,
             .woodCreakingAlt, .waterShallow, .grassAlt:
            true
        }
    }

    /// Whether line of sight *enters* the cell. GemRB's `AREImporter` table
    /// marks only index 0 as `NO_SEE`. Index 10 is `SIDEWALL` — the cell itself
    /// is visible, then the ray blocks on leaving the run — and index 13 (roof)
    /// does not block sight. `isSightSidewall` is the other half of that table.
    var isSeeThrough: Bool {
        self != .obstacle
    }

    /// Search-map index 10. A ray that is already on sidewall stays visible;
    /// the first non-sidewall cell after the run starts the `Pass = 2` stop.
    var isSightSidewall: Bool {
        self == .wall
    }

    /// The area-mask nibble this terrain index contributes to the search map.
    ///
    /// GemRB's `AREImporter` builds exactly this from the same table: index 0 is
    /// `NO_SEE`, index 10 is `SIDEWALL`, index 14 is `TRAVEL`, and anything a
    /// creature can stand on carries `PASSABLE`. Deriving the whole nibble here
    /// keeps one source of truth — a painted map and its flag byte cannot
    /// disagree, and adding a terrain index cannot forget to set a bit.
    var areaFlags: PathMapFlags {
        var flags: PathMapFlags = []
        if isWalkable { flags.insert(.passable) }
        if self == .worldMapExit { flags.insert(.travel) }
        if !isSeeThrough { flags.insert(.noSee) }
        if isSightSidewall { flags.insert(.sidewall) }
        return flags
    }

    /// Whether a flying creature can cross.
    var isFlyable: Bool {
        switch self {
        case .obstacle, .wall, .roof: false
        default: true
        }
    }

    /// Whether a projectile passes.
    var allowsProjectiles: Bool {
        switch self {
        case .obstacle, .wall, .roof: false
        default: true
        }
    }

    var surface: SearchMapSurface {
        switch self {
        case .obstacle, .obstacleSeeThrough, .wall, .waterImpassable, .roof, .worldMapExit:
            .silent
        case .wood, .woodCreaking, .woodCreakingAlt:
            .wood
        case .stone, .stoneEchoey:
            .stone
        case .sand:
            .sand
        case .grass, .grassAlt:
            .grass
        case .water, .waterShallow:
            .water
        }
    }

    /// The engine's own footstep resref for this index, kept as documentation of
    /// which BG sample a cell would have played. RainShadow resolves audio
    /// through `surface`; this is here so a value can be checked against the
    /// table it came from.
    var infinityEngineWalkSound: String? {
        switch self {
        case .obstacle, .obstacleSeeThrough, .wall, .waterImpassable, .roof, .worldMapExit:
            nil
        case .sand, .grassAlt: "WAL_04"
        case .wood: "WAL_MT"
        case .woodCreaking, .woodCreakingAlt: "WAL_02"
        case .stoneEchoey: "WAL_05"
        case .grass: "WAL_06"
        case .water, .waterShallow: "WAL_01"
        case .stone: "WAL_03"
        }
    }

    /// Palette entry BG paints this index with, as 8-bit sRGB.
    ///
    /// The bake and QA scripts write and read indexed PNGs, so the runtime never
    /// needs these — they are here so a search map can be rendered for review in
    /// the colours the Infinity Engine documentation shows, and so the Python
    /// side has one authority to copy rather than its own transcription.
    var reviewColor: (r: UInt8, g: UInt8, b: UInt8) {
        switch self {
        case .obstacle: (0, 0, 0)                    // black
        case .sand: (128, 0, 32)                     // burgundy
        case .wood: (0, 100, 0)                      // dark green
        case .woodCreaking: (139, 105, 20)           // brown / dark yellow
        case .stoneEchoey: (0, 0, 139)               // dark blue
        case .grass: (128, 0, 128)                   // purple
        case .water: (64, 224, 208)                  // turquoise
        case .stone: (192, 192, 192)                 // light grey
        case .obstacleSeeThrough: (64, 64, 64)       // dark grey
        case .woodCreakingAlt: (255, 0, 0)           // red
        case .wall: (0, 255, 0)                      // bright green
        case .waterShallow: (255, 255, 0)            // yellow
        case .waterImpassable: (0, 0, 255)           // blue
        case .roof: (255, 0, 255)                    // magenta
        case .worldMapExit: (0, 255, 255)            // cyan
        case .grassAlt: (255, 255, 255)              // white
        }
    }

    /// Decode a stored byte, treating anything outside the table as solid.
    ///
    /// Deliberately not `?? .stone`: an unreadable cell must not become floor.
    /// A bad bake should strand the player, which is visible, rather than open a
    /// hole in a wall, which is not.
    static func decode(_ raw: UInt8) -> SearchMapTerrain {
        SearchMapTerrain(rawValue: raw) ?? .obstacle
    }

    /// Authoring name. The raw value has to stay the Infinity Engine index
    /// because a painted search map stores exactly that byte, so area JSON
    /// spells the name instead — `"wood"` reads as ground, `2` reads as nothing.
    var name: String {
        switch self {
        case .obstacle: "obstacle"
        case .sand: "sand"
        case .wood: "wood"
        case .woodCreaking: "wood-creaking"
        case .stoneEchoey: "stone-echoey"
        case .grass: "grass"
        case .water: "water"
        case .stone: "stone"
        case .obstacleSeeThrough: "obstacle-see-through"
        case .woodCreakingAlt: "wood-creaking-alt"
        case .wall: "wall"
        case .waterShallow: "water-shallow"
        case .waterImpassable: "water-impassable"
        case .roof: "roof"
        case .worldMapExit: "worldmap-exit"
        case .grassAlt: "grass-alt"
        }
    }

    static func named(_ name: String) -> SearchMapTerrain? {
        allCases.first { $0.name == name }
    }
}

extension SearchMapTerrain: Codable {
    init(from decoder: Decoder) throws {
        let name = try decoder.singleValueContainer().decode(String.self)
        guard let terrain = SearchMapTerrain.named(name) else {
            throw DecodingError.dataCorrupted(
                .init(
                    codingPath: decoder.codingPath,
                    debugDescription: "'\(name)' is not a search-map terrain"
                )
            )
        }
        self = terrain
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(name)
    }
}
