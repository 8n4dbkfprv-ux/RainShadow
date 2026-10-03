import Foundation

/// Permanent area resrefs. Never recycle a code or derive it from catalog order.
/// Resource basenames remain descriptive; old saves and authoring tools may use them.
public enum AreaResourceID {
    public static let codes: [String: String] = [
        "opening_exterior": "RS0000",
        "city_sable_row": "RS0100", "office_suite": "RS0101",
        "city_wharf_ladder": "RS0200", "interior_shipping_office": "RS0201",
        "city_riverside": "RS0300", "interior_iron_stairs": "RS0301",
        "city_lamp_ward": "RS0400", "interior_lamphouse": "RS0401",
        "city_lila_street": "RS0500", "interior_lila_rooms": "RS0501",
        "city_civic_records": "RS0600", "interior_records_annex": "RS0601",
        "city_harborpoint_pd": "RS0700", "interior_police_station": "RS0701",
        "sable_court": "RS9900", "sable_noir": "RS9901"
    ]

    public static func canonical(_ name: String) -> String {
        if let code = codes[name.lowercased()] { return code }
        let upper = name.uppercased()
        return codes.values.contains(upper) ? upper : name
    }

    public static func resourceName(_ name: String) -> String {
        let code = canonical(name)
        return codes.first { $0.value == code }?.key ?? name
    }
}

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
            id: LegacySaveIDs.itemID(try c.decode(String.self, forKey: .id)),
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
            id: LegacySaveIDs.itemID(try c.decode(String.self, forKey: .id)),
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

/// Area and item ids renamed after saves were written, old → new.
///
/// Applied where area-keyed state is decoded, so a save from before the rename
/// keeps its dropped items and area variables (Lamp Ward's visited flag among
/// them). Portal ids, district and interior raw values are never persisted, so
/// only area ids and renamed item ids need mapping.
enum LegacySaveIDs {
    /// Harborpoint PD became Lamp Ward; its station became the Lamphouse.
    /// `AreaResourceID` then folds those names onto RS0400 / RS0401.
    /// Lila's Street stays the central district on the restored map.
    static let areaIDs: [String: String] = [
        "city_harborpoint_pd": "city_lamp_ward",
        "interior_police_station": "interior_lamphouse"
    ]

    static func areaID(_ id: String) -> String {
        areaIDs[id] ?? id
    }

    /// Item ids renamed after saves were written, old → new: the modern starter
    /// kit became the Lantern shortsword, the dark lantern, the coin purse and
    /// the tobacco tin; the Blue Room matchbook became a brass tavern token.
    static let itemIDs: [String: String] = [
        "service-revolver": "lantern-shortsword",
        "flashlight": "dark-lantern",
        "wallet": "coin-purse",
        "cigarette-case": "tobacco-tin",
        "matchbook": "blue-room-token"
    ]

    static func itemID(_ id: String) -> String {
        itemIDs[id] ?? id
    }

    /// Loot container stacks carry item ids too.
    static func renamedLoot(_ stacks: [PersistedLootStack]) -> [PersistedLootStack] {
        stacks.map { stack in
            if case .item(let id, let quantity) = stack {
                return .item(id: itemID(id), quantity: quantity)
            }
            return stack
        }
    }

    /// Re-keys a dictionary keyed by area id. A value already stored under the
    /// new id wins over one carried forward from the old id.
    static func rekeyedByArea<Value>(_ values: [String: Value]) -> [String: Value] {
        var rekeyed: [String: Value] = [:]
        for (key, value) in values where areaIDs[key] == nil {
            rekeyed[key] = value
        }
        for (key, value) in values {
            guard let renamed = areaIDs[key], rekeyed[renamed] == nil else { continue }
            rekeyed[renamed] = value
        }
        return rekeyed
    }

    /// Re-keys flattened `"<area id>/<name>"` area-variable keys, splitting on the
    /// first slash exactly as `AreaVariables(flattened:)` does.
    static func rekeyedAreaVariables<Value>(_ values: [String: Value]) -> [String: Value] {
        var rekeyed: [String: Value] = [:]
        var carried: [(key: String, value: Value)] = []
        for (key, value) in values {
            guard let slash = key.firstIndex(of: "/"),
                  let renamed = areaIDs[String(key[..<slash])] else {
                rekeyed[key] = value
                continue
            }
            carried.append((key: renamed + String(key[slash...]), value: value))
        }
        for entry in carried where rekeyed[entry.key] == nil {
            rekeyed[entry.key] = entry.value
        }
        return rekeyed
    }
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
    /// Modified ARE object flags, keyed by area then object. Additive defaults
    /// preserve old saves and let unvisited objects use authored start states.
    var areaDoorOpen: [String: [String: Bool]] = [:]
    var areaUnlockedDoors: [String: Set<String>] = [:]
    var areaSpentTriggers: [String: Set<String>] = [:]
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
        exploredFog: [String: PersistedExploredFog] = [:],
        areaDoorOpen: [String: [String: Bool]] = [:],
        areaUnlockedDoors: [String: Set<String>] = [:],
        areaSpentTriggers: [String: Set<String>] = [:]
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
        self.areaDoorOpen = areaDoorOpen
        self.areaUnlockedDoors = areaUnlockedDoors
        self.areaSpentTriggers = areaSpentTriggers
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
        lootContainers = (try container.decodeIfPresent(
            [String: [PersistedLootStack]].self,
            forKey: .lootContainers
        ) ?? [:]).mapValues(LegacySaveIDs.renamedLoot)
        carriedItems = try container.decodeIfPresent(
            [PersistedCarriedItemStack].self,
            forKey: .carriedItems
        ) ?? []
        equippedItems = try container.decodeIfPresent(
            [String: PersistedCarriedItemStack].self,
            forKey: .equippedItems
        ) ?? [:]
        groundPiles = LegacySaveIDs.rekeyedByArea(try container.decodeIfPresent(
            [String: [PersistedGroundItemStack]].self,
            forKey: .groundPiles
        ) ?? [:])
        hasSeededStarterKit =
            try container.decodeIfPresent(Bool.self, forKey: .hasSeededStarterKit) ?? false
        caseFlags = try container.decodeIfPresent(Set<String>.self, forKey: .caseFlags) ?? []
        caseKnowledgeIDs = try container.decodeIfPresent(Set<String>.self, forKey: .caseKnowledgeIDs) ?? []
        caseEvidenceIDs = try container.decodeIfPresent(Set<String>.self, forKey: .caseEvidenceIDs) ?? []
        caseJournalFragments = try container.decodeIfPresent(
            [PersistedJournalFragment].self,
            forKey: .caseJournalFragments
        ) ?? []
        areaVariables = LegacySaveIDs.rekeyedAreaVariables(try container.decodeIfPresent(
            [String: PersistedAreaVariable].self,
            forKey: .areaVariables
        ) ?? [:])
        caseCounters = try container.decodeIfPresent([String: Int].self, forKey: .caseCounters) ?? [:]
        areaDoorOpen = try container.decodeIfPresent([String: [String: Bool]].self, forKey: .areaDoorOpen) ?? [:]
        areaUnlockedDoors = try container.decodeIfPresent([String: Set<String>].self, forKey: .areaUnlockedDoors) ?? [:]
        areaSpentTriggers = try container.decodeIfPresent([String: Set<String>].self, forKey: .areaSpentTriggers) ?? [:]
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
            for (legacyArea, arrival) in Self.rebuiltAreaArrivals {
                for area in [legacyArea, AreaResourceID.canonical(legacyArea)] {
                    snapshot.exploredFog.removeValue(forKey: area)
                    if let piles = snapshot.groundPiles[area] {
                        snapshot.groundPiles[area] = piles.map { old in
                            var item = old
                            item.x = arrival.x; item.y = arrival.y
                            return item
                        }
                    }
                }
            }
            snapshot.cityLayoutRevision = 1
            save(snapshot)
        }
        if snapshot.officeLayoutRevision < 1 {
            let backupKey = key + ".BeforeOfficeLayoutV19"
            if defaults.data(forKey: backupKey) == nil { defaults.set(data, forKey: backupKey) }
            for area in ["office_suite", AreaResourceID.canonical("office_suite")] {
                snapshot.exploredFog.removeValue(forKey: area)
                if let piles = snapshot.groundPiles[area] {
                    snapshot.groundPiles[area] = piles.map { old in
                        var item = old
                        item.x = Self.restoredOfficeArrival.x; item.y = Self.restoredOfficeArrival.y
                        return item
                    }
                }
            }
            snapshot.officeLayoutRevision = 1
            save(snapshot)
        }
        let normalized = snapshot.withCanonicalAreaIDs()
        if normalized != snapshot {
            let backupKey = key + ".BeforeAreaCodesV1"
            if defaults.data(forKey: backupKey) == nil { defaults.set(data, forKey: backupKey) }
            save(normalized)
        }
        return normalized
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

private extension SaveSnapshot {
    func withCanonicalAreaIDs() -> SaveSnapshot {
        // Aliases first, canonical keys last: canonical values win conflicts.
        func migrate<T>(_ source: [String: T], key: (String) -> String = AreaResourceID.canonical,
                        merge: (T, T) -> T) -> [String: T] {
            var result: [String: T] = [:]
            let ordered = source.keys.sorted {
                let a = key($0) == $0, b = key($1) == $1
                return a == b ? $0 < $1 : !a
            }
            for old in ordered {
                let new = key(old), value = source[old]!
                result[new] = result[new].map { merge($0, value) } ?? value
            }
            return result
        }
        var result = self
        result.groundPiles = migrate(groundPiles, merge: +)
        result.areaDoorOpen = migrate(areaDoorOpen) { $0.merging($1) { _, canonical in canonical } }
        result.areaUnlockedDoors = migrate(areaUnlockedDoors) { $0.union($1) }
        result.areaSpentTriggers = migrate(areaSpentTriggers) { $0.union($1) }
        result.areaVariables = migrate(areaVariables, key: { key in
            guard let slash = key.firstIndex(of: "/") else { return key }
            return AreaResourceID.canonical(String(key[..<slash])) + key[slash...]
        }) { _, canonical in canonical }
        result.exploredFog = migrate(exploredFog) { old, canonical in
            guard old.columns == canonical.columns, old.rows == canonical.rows,
                  old.bytes.count == canonical.bytes.count else { return canonical }
            return PersistedExploredFog(columns: canonical.columns, rows: canonical.rows,
                                        bytes: Data(zip(old.bytes, canonical.bytes).map { $0 | $1 }))
        }
        return result
    }
}
