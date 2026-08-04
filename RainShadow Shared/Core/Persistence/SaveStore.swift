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
    var inspectedHotspotIDs: Set<String> = []
    /// Wallet balance in pence. Default matches the prior cosmetic £7 4s display.
    var walletPence: Int = 1_728
    /// BG resolve-once container contents, keyed by container/hotspot ID.
    var lootContainers: [String: [PersistedLootStack]] = [:]

    init(
        schemaVersion: Int = 1,
        hasSeenOpening: Bool = false,
        hasSeenOfficeHint: Bool = false,
        inspectedHotspotIDs: Set<String> = [],
        walletPence: Int = 1_728,
        lootContainers: [String: [PersistedLootStack]] = [:]
    ) {
        self.schemaVersion = schemaVersion
        self.hasSeenOpening = hasSeenOpening
        self.hasSeenOfficeHint = hasSeenOfficeHint
        self.inspectedHotspotIDs = inspectedHotspotIDs
        self.walletPence = walletPence
        self.lootContainers = lootContainers
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        hasSeenOpening = try container.decodeIfPresent(Bool.self, forKey: .hasSeenOpening) ?? false
        hasSeenOfficeHint = try container.decodeIfPresent(Bool.self, forKey: .hasSeenOfficeHint) ?? false
        inspectedHotspotIDs = try container.decodeIfPresent(Set<String>.self, forKey: .inspectedHotspotIDs) ?? []
        walletPence = try container.decodeIfPresent(Int.self, forKey: .walletPence) ?? 1_728
        lootContainers = try container.decodeIfPresent(
            [String: [PersistedLootStack]].self,
            forKey: .lootContainers
        ) ?? [:]
    }
}

@MainActor
final class SaveStore {
    private let defaults: UserDefaults
    private let key: String
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard, key: String = "RainShadow.Save.v1") {
        self.defaults = defaults
        self.key = key
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
}
