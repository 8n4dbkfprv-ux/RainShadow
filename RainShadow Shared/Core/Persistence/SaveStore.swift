import Foundation

struct SaveSnapshot: Codable, Equatable {
    var schemaVersion = 1
    var hasSeenOpening = false
    var hasSeenOfficeHint = false
    var inspectedHotspotIDs: Set<String> = []
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
