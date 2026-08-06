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
            hasCompletedOfficeCaseIntro: true,
            inspectedHotspotIDs: ["office.window", "office.files"],
            caseFlags: ["empty-coat.case.client-retained"]
        )

        store.save(expected)

        #expect(store.load() == expected)
        #expect(store.load().hasCompletedOfficeCaseIntro)
        #expect(store.load().caseFlags.contains("empty-coat.case.client-retained"))
    }

    @Test func legacySaveWithoutIntroFlagDefaultsFalse() throws {
        let suiteName = "RainShadowTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = SaveStore(defaults: defaults, key: "save")
        store.save(SaveSnapshot(hasSeenOpening: true))
        let loaded = store.load()
        #expect(loaded.hasSeenOpening)
        #expect(!loaded.hasCompletedOfficeCaseIntro)
        #expect(loaded.caseFlags.isEmpty)
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
