import Foundation

/// Persistence mirror of Core `ResolvedLootStack` — Persistence has no Core dependency.
enum PersistedLootStack: Codable, Equatable, Sendable {
    case coins(pence: Int)
    case item(id: String, quantity: Int)
}

/// Persistence mirror of Core `CarriedItemStack`.
///
/// `isIdentified` and `charges` arrived after the first saves were written, so
/// both decode with a default: a stack recorded before identification existed
/// was, in fact, identified.
struct PersistedCarriedItemStack: Codable, Equatable, Sendable {
    var id: String
    var quantity: Int
    var isIdentified: Bool
    var charges: Int?

    init(id: String, quantity: Int, isIdentified: Bool = true, charges: Int? = nil) {
        self.id = id
        self.quantity = quantity
        self.isIdentified = isIdentified
        self.charges = charges
    }

    private enum CodingKeys: String, CodingKey {
        case id, quantity, isIdentified, charges
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try c.decode(String.self, forKey: .id),
            quantity: try c.decode(Int.self, forKey: .quantity),
            isIdentified: try c.decodeIfPresent(Bool.self, forKey: .isIdentified) ?? true,
            charges: try c.decodeIfPresent(Int.self, forKey: .charges)
        )
    }
}

/// Persistence mirror of Core `GroundItemStack`. Items dropped on the floor of an
/// area stay there across a relaunch, the way BG leaves a pile where it fell.
struct PersistedGroundItemStack: Codable, Equatable, Sendable {
    var id: String
    var quantity: Int
    var isIdentified: Bool
    var charges: Int?
    var x: Double
    var y: Double

    init(
        id: String,
        quantity: Int,
        isIdentified: Bool = true,
        charges: Int? = nil,
        x: Double,
        y: Double
    ) {
        self.id = id
        self.quantity = quantity
        self.isIdentified = isIdentified
        self.charges = charges
        self.x = x
        self.y = y
    }

    private enum CodingKeys: String, CodingKey {
        case id, quantity, isIdentified, charges, x, y
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try c.decode(String.self, forKey: .id),
            quantity: try c.decode(Int.self, forKey: .quantity),
            isIdentified: try c.decodeIfPresent(Bool.self, forKey: .isIdentified) ?? true,
            charges: try c.decodeIfPresent(Int.self, forKey: .charges),
            x: try c.decodeIfPresent(Double.self, forKey: .x) ?? 0,
            y: try c.decodeIfPresent(Double.self, forKey: .y) ?? 0
        )
    }
}

/// Persistence mirror of Core `QueuedJournalFragment` — same no-Core-dependency rule
/// as `PersistedLootStack`. Kept structurally identical so the two-way map stays trivial.
/// One area variable in the save file.
///
/// `RainShadowPersistence` is Foundation-only and deliberately knows nothing of
/// `RainShadowCore`, so this mirrors `AreaVariableValue` rather than importing
/// it — the same arrangement every other persisted type here uses. The tag is
/// spelled out so a save stays readable, and an unknown one decodes as an
/// integer zero rather than failing the whole load.
struct PersistedAreaVariable: Codable, Equatable, Sendable {
    /// `"integer"`, `"number"` or `"text"`.
    var kind: String
    var integer: Int?
    var number: Double?
    var text: String?

    init(kind: String, integer: Int? = nil, number: Double? = nil, text: String? = nil) {
        self.kind = kind
        self.integer = integer
        self.number = number
        self.text = text
    }
}

struct PersistedJournalFragment: Codable, Equatable, Sendable {
    var id: String
    /// e.g. `"chronology"` or `"lead"`.
    var kind: String
    var text: String

    init(id: String, kind: String, text: String) {
        self.id = id
        self.kind = kind
        self.text = text
    }
}

/// One area's explored bitmask, with the grid dimensions it was written at —
/// a bitmask is meaningless without the width its rows were counted at.
struct PersistedExploredFog: Codable, Equatable {
    var columns: Int
    var rows: Int
    /// Encodes as base64 in the save file, the way `Data` always does.
    var bytes: Data
}

struct SaveSnapshot: Codable, Equatable {
    /// Newest envelope this binary writes. `load()` accepts anything at or below it,
    /// so an additive field never has to bump — and a real bump never wipes a save.
    static let currentSchemaVersion = 1

    var cityLayoutRevision = 1
    var officeLayoutRevision = 1
    var schemaVersion = SaveSnapshot.currentSchemaVersion
    var hasSeenOpening = false
    var hasSeenOfficeHint = false
    /// BG:EE-style one-shot: Empty Coat office intro + Lila visit finished (no replay on re-enter).
    var hasCompletedOfficeCaseIntro = false
    var inspectedHotspotIDs: Set<String> = []
    /// Wallet balance in pence. Default matches the prior cosmetic £7 4s display.
    var walletPence: Int = 1_728
    /// BG resolve-once container contents, keyed by container/hotspot ID.
    var lootContainers: [String: [PersistedLootStack]] = [:]
    /// Every stack in the case bag, including the starter kit once it has been
    /// seeded. Saves written before `hasSeededStarterKit` existed hold acquired
    /// stacks only; the seed pass tops them up on next load.
    var carriedItems: [PersistedCarriedItemStack] = []
    /// Worn and readied items, keyed by `EquipmentSlot.rawValue`. Persistence has
    /// no Core dependency, so the slot arrives as its raw string and an unknown
    /// key is dropped on load rather than failing the save.
    var equippedItems: [String: PersistedCarriedItemStack] = [:]
    /// Items dropped on the floor, keyed by area id.
    var groundPiles: [String: [PersistedGroundItemStack]] = [:]
    /// Whether the six painted starter items have been promoted from a reserved
    /// slot count into real stacks. One-way: it is set the first time a save is
    /// loaded by a binary that knows how to seed them.
    var hasSeededStarterKit = false
    /// Case flags earned in dialogue (e.g. client retained) — survives area change / relaunch.
    var caseFlags: Set<String> = []
    /// Knowledge ids granted in dialogue. The Infinity Engine persists every GLOBAL in
    /// the `.gam`; storing only flags silently regressed `hasKnowledge` gates on relaunch.
    var caseKnowledgeIDs: Set<String> = []
    /// Evidence ids granted in dialogue — feeds `hasEvidence` gates across sessions.
    var caseEvidenceIDs: Set<String> = []
    /// Journal fragments earned in dialogue, projected into the casebook.
    var caseJournalFragments: [PersistedJournalFragment] = []
    /// Integer case counters (IE `Global` with a numeric value), including the
    /// reserved `talk.<ownerID>` conversation counts behind `NumTimesTalkedTo`.
    var caseCounters: [String: Int] = [:]
    /// Area-scoped variables, flattened to `"<scope>/<name>"` keys.
    ///
    /// Baldur's Gate saves the modified `.ARE`, variables section included; this
    /// is the equivalent. Defaulted so a save written before it existed loads
    /// with an empty store rather than failing.
    var areaVariables: [String: PersistedAreaVariable] = [:]
    /// Each area's explored bitmask, keyed by area id.
    ///
    /// Baldur's Gate saves this in the area's own record — "an array of bits, one
    /// bit for each 32x32 cell" — which is what lets a place you have walked stay
    /// drawn when you come back to it. Defaulted, so a save written before it
    /// existed loads with nothing explored rather than failing.
    var exploredFog: [String: PersistedExploredFog] = [:]

    init(
        schemaVersion: Int = SaveSnapshot.currentSchemaVersion,
        hasSeenOpening: Bool = false,
        hasSeenOfficeHint: Bool = false,
        hasCompletedOfficeCaseIntro: Bool = false,
        inspectedHotspotIDs: Set<String> = [],
        walletPence: Int = 1_728,
        lootContainers: [String: [PersistedLootStack]] = [:],
        carriedItems: [PersistedCarriedItemStack] = [],
        equippedItems: [String: PersistedCarriedItemStack] = [:],
        groundPiles: [String: [PersistedGroundItemStack]] = [:],
        hasSeededStarterKit: Bool = false,
        caseFlags: Set<String> = [],
        caseKnowledgeIDs: Set<String> = [],
        caseEvidenceIDs: Set<String> = [],
        caseJournalFragments: [PersistedJournalFragment] = [],
        caseCounters: [String: Int] = [:],
        areaVariables: [String: PersistedAreaVariable] = [:],
        exploredFog: [String: PersistedExploredFog] = [:]
    ) {
        self.schemaVersion = schemaVersion
        self.hasSeenOpening = hasSeenOpening
        self.hasSeenOfficeHint = hasSeenOfficeHint
        self.hasCompletedOfficeCaseIntro = hasCompletedOfficeCaseIntro
        self.inspectedHotspotIDs = inspectedHotspotIDs
        self.walletPence = walletPence
        self.lootContainers = lootContainers
        self.carriedItems = carriedItems
        self.equippedItems = equippedItems
        self.groundPiles = groundPiles
        self.hasSeededStarterKit = hasSeededStarterKit
        self.caseFlags = caseFlags
        self.caseKnowledgeIDs = caseKnowledgeIDs
        self.caseEvidenceIDs = caseEvidenceIDs
        self.caseJournalFragments = caseJournalFragments
        self.caseCounters = caseCounters
        self.areaVariables = areaVariables
        self.exploredFog = exploredFog
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        cityLayoutRevision = try container.decodeIfPresent(Int.self, forKey: .cityLayoutRevision) ?? 0
        officeLayoutRevision = try container.decodeIfPresent(Int.self, forKey: .officeLayoutRevision) ?? 0
        exploredFog = try container.decodeIfPresent([String: PersistedExploredFog].self, forKey: .exploredFog) ?? [:]
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion)
            ?? SaveSnapshot.currentSchemaVersion
        hasSeenOpening = try container.decodeIfPresent(Bool.self, forKey: .hasSeenOpening) ?? false
        hasSeenOfficeHint = try container.decodeIfPresent(Bool.self, forKey: .hasSeenOfficeHint) ?? false
        hasCompletedOfficeCaseIntro =
            try container.decodeIfPresent(Bool.self, forKey: .hasCompletedOfficeCaseIntro) ?? false
        inspectedHotspotIDs = try container.decodeIfPresent(Set<String>.self, forKey: .inspectedHotspotIDs) ?? []
        walletPence = try container.decodeIfPresent(Int.self, forKey: .walletPence) ?? 1_728
        lootContainers = try container.decodeIfPresent(
            [String: [PersistedLootStack]].self,
            forKey: .lootContainers
        ) ?? [:]
        carriedItems = try container.decodeIfPresent(
            [PersistedCarriedItemStack].self,
            forKey: .carriedItems
        ) ?? []
        equippedItems = try container.decodeIfPresent(
            [String: PersistedCarriedItemStack].self,
            forKey: .equippedItems
        ) ?? [:]
        groundPiles = try container.decodeIfPresent(
            [String: [PersistedGroundItemStack]].self,
            forKey: .groundPiles
        ) ?? [:]
        hasSeededStarterKit =
            try container.decodeIfPresent(Bool.self, forKey: .hasSeededStarterKit) ?? false
        caseFlags = try container.decodeIfPresent(Set<String>.self, forKey: .caseFlags) ?? []
        caseKnowledgeIDs = try container.decodeIfPresent(Set<String>.self, forKey: .caseKnowledgeIDs) ?? []
        caseEvidenceIDs = try container.decodeIfPresent(Set<String>.self, forKey: .caseEvidenceIDs) ?? []
        caseJournalFragments = try container.decodeIfPresent(
            [PersistedJournalFragment].self,
            forKey: .caseJournalFragments
        ) ?? []
        areaVariables = try container.decodeIfPresent(
            [String: PersistedAreaVariable].self,
            forKey: .areaVariables
        ) ?? [:]
        caseCounters = try container.decodeIfPresent([String: Int].self, forKey: .caseCounters) ?? [:]
    }
}

@MainActor
final class SaveStore {
    private let defaults: UserDefaults
    private let key: String
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    /// Discards the persisted snapshot at launch, so one-shot state replays.
    ///
    /// The Infinity Engine keeps this kind of "already happened" state as GLOBAL
    /// variables inside the `.gam` save, which means a finished cinematic can
    /// only be seen again by starting a new game — or by zeroing the variable
    /// from the console (`SetGlobal("...","GLOBAL",0)`). RainShadow has neither
    /// a new-game affordance nor a console yet, so without this hook
    /// `hasCompletedOfficeCaseIntro` is unreachable once it has been set and the
    /// office intro can never be tested again on that machine.
    ///
    /// Set `RAINSHADOW_RESET_SAVE=1` in the environment to use it.
    init(
        defaults: UserDefaults = .standard,
        key: String = "RainShadow.Save.v1",
        resetsOnLaunch: Bool = ProcessInfo.processInfo.environment["RAINSHADOW_RESET_SAVE"] == "1"
    ) {
        self.defaults = defaults
        self.key = key
        if resetsOnLaunch {
            defaults.removeObject(forKey: key)
        }
    }

    /// Accepts any envelope this binary understands — at or below
    /// `currentSchemaVersion`. Every field added since v1 decodes as optional with a
    /// default, so an older snapshot loads intact rather than being discarded. A
    /// *newer* snapshot is rejected: it may carry state this binary would silently
    /// drop and then write back.
    func load() -> SaveSnapshot {
        guard let data = defaults.data(forKey: key),
              var snapshot = try? decoder.decode(SaveSnapshot.self, from: data),
              snapshot.schemaVersion <= SaveSnapshot.currentSchemaVersion else {
            return SaveSnapshot()
        }
        if snapshot.cityLayoutRevision < 1 {
            // Keep the original envelope before moving spatial state onto the
            // reviewed layouts. Story, inventory and journal fields stay intact.
            let backupKey = key + ".BeforeCityLayoutV1"
            if defaults.data(forKey: backupKey) == nil { defaults.set(data, forKey: backupKey) }
            for (area, arrival) in Self.rebuiltAreaArrivals {
                snapshot.exploredFog.removeValue(forKey: area)
                if let piles = snapshot.groundPiles[area] {
                    snapshot.groundPiles[area] = piles.map { old in
                        var item = old
                        item.x = arrival.x; item.y = arrival.y
                        return item
                    }
                }
            }
            snapshot.cityLayoutRevision = 1
            save(snapshot)
        }
        if snapshot.officeLayoutRevision < 1 {
            let backupKey = key + ".BeforeOfficeLayoutV19"
            if defaults.data(forKey: backupKey) == nil { defaults.set(data, forKey: backupKey) }
            snapshot.exploredFog.removeValue(forKey: "office_suite")
            if let piles = snapshot.groundPiles["office_suite"] {
                snapshot.groundPiles["office_suite"] = piles.map { old in
                    var item = old
                    item.x = Self.restoredOfficeArrival.x; item.y = Self.restoredOfficeArrival.y
                    return item
                }
            }
            snapshot.officeLayoutRevision = 1
            save(snapshot)
        }
        return snapshot
    }

    // OfficeRestoreTests checks this against the V19 ARE default entrance.
    static let restoredOfficeArrival = (x: 2163.2192390326964, y: 1377.3108219558917)

    // Foundation-only mirror of the five restored ARE default entrances.
    // RebuiltCityAreaTests checks these against the actual navigation rasters.
    static let rebuiltAreaArrivals: [String: (x: Double, y: Double)] = [
        "city_sable_row": (1578, 1815),
        "city_wharf_ladder": (1933.6086, 1896.6323),
        "city_riverside": (1592, 1902),
        "interior_shipping_office": (384.2851, 255.2533),
        "interior_iron_stairs": (344, 222)
    ]

    func save(_ snapshot: SaveSnapshot) {
        guard let data = try? encoder.encode(snapshot) else { return }
        defaults.set(data, forKey: key)
    }

    /// Discards persisted progress.
    ///
    /// A live `GameSession` copies the snapshot at construction, so this only
    /// takes effect once the session is rebuilt — see `GameBootstrap.startNewGame`.
    /// Clearing the key rather than writing a blank snapshot means a future
    /// schema bump starts from `SaveSnapshot()`'s defaults rather than from
    /// today's idea of "empty".
    func reset() {
        defaults.removeObject(forKey: key)
    }
}
