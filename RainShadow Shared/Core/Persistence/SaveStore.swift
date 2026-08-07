import Foundation

/// Persistence mirror of Core `ResolvedLootStack` — Persistence has no Core dependency.
enum PersistedLootStack: Codable, Equatable, Sendable {
    case coins(pence: Int)
    case item(id: String, quantity: Int)
}

struct SaveSnapshot: Codable, Equatable {
    var schemaVersion = 1
    var hasSeenOpening = false
    var hasSeenOfficeHint = false
    /// BG:EE-style one-shot: Empty Coat office intro + Lila visit finished (no replay on re-enter).
    var hasCompletedOfficeCaseIntro = false
    var inspectedHotspotIDs: Set<String> = []
    /// Wallet balance in pence. Default matches the prior cosmetic £7 4s display.
    var walletPence: Int = 1_728
    /// BG resolve-once container contents, keyed by container/hotspot ID.
    var lootContainers: [String: [PersistedLootStack]] = [:]
    /// Case flags earned in dialogue (e.g. client retained) — survives area change / relaunch.
    var caseFlags: Set<String> = []

    init(
        schemaVersion: Int = 1,
        hasSeenOpening: Bool = false,
        hasSeenOfficeHint: Bool = false,
        hasCompletedOfficeCaseIntro: Bool = false,
        inspectedHotspotIDs: Set<String> = [],
        walletPence: Int = 1_728,
        lootContainers: [String: [PersistedLootStack]] = [:],
        caseFlags: Set<String> = []
    ) {
        self.schemaVersion = schemaVersion
        self.hasSeenOpening = hasSeenOpening
        self.hasSeenOfficeHint = hasSeenOfficeHint
        self.hasCompletedOfficeCaseIntro = hasCompletedOfficeCaseIntro
        self.inspectedHotspotIDs = inspectedHotspotIDs
        self.walletPence = walletPence
        self.lootContainers = lootContainers
        self.caseFlags = caseFlags
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
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
        caseFlags = try container.decodeIfPresent(Set<String>.self, forKey: .caseFlags) ?? []
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

    func load() -> SaveSnapshot {
        guard let data = defaults.data(forKey: key),
              let snapshot = try? decoder.decode(SaveSnapshot.self, from: data),
              snapshot.schemaVersion == 1 else {
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
