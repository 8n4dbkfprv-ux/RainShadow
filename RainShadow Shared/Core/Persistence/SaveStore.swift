import Foundation

/// Persistence mirror of Core `ResolvedLootStack` — Persistence has no Core dependency.
enum PersistedLootStack: Codable, Equatable, Sendable {
    case coins(pence: Int)
    case item(id: String, quantity: Int)
}

/// Persistence mirror of Core `CarriedItemStack`. Static starter-kit entries are
/// intentionally not stored; older saves therefore gain an empty acquired bag.
struct PersistedCarriedItemStack: Codable, Equatable, Sendable {
    var id: String
    var quantity: Int

    init(id: String, quantity: Int) {
        self.id = id
        self.quantity = quantity
    }
}

/// Persistence mirror of Core `QueuedJournalFragment` — same no-Core-dependency rule
/// as `PersistedLootStack`. Kept structurally identical so the two-way map stays trivial.
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

struct SaveSnapshot: Codable, Equatable {
    /// Newest envelope this binary writes. `load()` accepts anything at or below it,
    /// so an additive field never has to bump — and a real bump never wipes a save.
    static let currentSchemaVersion = 1

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
    /// Acquired item stacks only. Six static starter items are supplied by the
    /// inventory presentation and occupy reserved slots at runtime.
    var carriedItems: [PersistedCarriedItemStack] = []
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

    init(
        schemaVersion: Int = SaveSnapshot.currentSchemaVersion,
        hasSeenOpening: Bool = false,
        hasSeenOfficeHint: Bool = false,
        hasCompletedOfficeCaseIntro: Bool = false,
        inspectedHotspotIDs: Set<String> = [],
        walletPence: Int = 1_728,
        lootContainers: [String: [PersistedLootStack]] = [:],
        carriedItems: [PersistedCarriedItemStack] = [],
        caseFlags: Set<String> = [],
        caseKnowledgeIDs: Set<String> = [],
        caseEvidenceIDs: Set<String> = [],
        caseJournalFragments: [PersistedJournalFragment] = [],
        caseCounters: [String: Int] = [:]
    ) {
        self.schemaVersion = schemaVersion
        self.hasSeenOpening = hasSeenOpening
        self.hasSeenOfficeHint = hasSeenOfficeHint
        self.hasCompletedOfficeCaseIntro = hasCompletedOfficeCaseIntro
        self.inspectedHotspotIDs = inspectedHotspotIDs
        self.walletPence = walletPence
        self.lootContainers = lootContainers
        self.carriedItems = carriedItems
        self.caseFlags = caseFlags
        self.caseKnowledgeIDs = caseKnowledgeIDs
        self.caseEvidenceIDs = caseEvidenceIDs
        self.caseJournalFragments = caseJournalFragments
        self.caseCounters = caseCounters
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
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
        caseFlags = try container.decodeIfPresent(Set<String>.self, forKey: .caseFlags) ?? []
        caseKnowledgeIDs = try container.decodeIfPresent(Set<String>.self, forKey: .caseKnowledgeIDs) ?? []
        caseEvidenceIDs = try container.decodeIfPresent(Set<String>.self, forKey: .caseEvidenceIDs) ?? []
        caseJournalFragments = try container.decodeIfPresent(
            [PersistedJournalFragment].self,
            forKey: .caseJournalFragments
        ) ?? []
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
              let snapshot = try? decoder.decode(SaveSnapshot.self, from: data),
              snapshot.schemaVersion <= SaveSnapshot.currentSchemaVersion else {
            return SaveSnapshot()
        }
        return snapshot
    }

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
