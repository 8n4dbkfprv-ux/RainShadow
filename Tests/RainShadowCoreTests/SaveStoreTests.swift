import Foundation
import Testing
@testable import RainShadowPersistence

@MainActor
struct SaveStoreTests {
    @Test func persistsAndRestoresMilestoneProgress() throws {
        let suiteName = "RainShadowTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = SaveStore(defaults: defaults, key: "save")
        let expected = SaveSnapshot(
            hasSeenOpening: true,
            hasSeenOfficeHint: true,
            inspectedHotspotIDs: ["office.window", "office.files"]
        )

        store.save(expected)

        #expect(store.load() == expected)
    }

    @Test func returnsSafeDefaultsForCorruptData() throws {
        let suiteName = "RainShadowTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(Data("not-json".utf8), forKey: "save")

        let store = SaveStore(defaults: defaults, key: "save")

        #expect(store.load() == SaveSnapshot())
    }
}
