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

extension SaveStoreTests {
    /// The Infinity Engine keeps one-shot progress as GLOBAL variables in the
    /// save, so a finished cinematic replays only on a new game. RainShadow has
    /// no new-game flow yet, so the launch reset is the only way back.
    @Test func launchResetDiscardsPersistedProgress() {
        let defaults = UserDefaults(suiteName: "RainShadow.SaveStoreTests.reset")!
        defaults.removePersistentDomain(forName: "RainShadow.SaveStoreTests.reset")

        var snapshot = SaveSnapshot()
        snapshot.hasCompletedOfficeCaseIntro = true
        snapshot.walletPence = 42
        SaveStore(defaults: defaults, resetsOnLaunch: false).save(snapshot)

        // Without the reset the one-shot gate survives, which is the shipped behaviour.
        let kept = SaveStore(defaults: defaults, resetsOnLaunch: false).load()
        #expect(kept.hasCompletedOfficeCaseIntro)
        #expect(kept.walletPence == 42)

        // With it, the next launch starts from a clean snapshot and the intro replays.
        let reset = SaveStore(defaults: defaults, resetsOnLaunch: true).load()
        #expect(!reset.hasCompletedOfficeCaseIntro)
        #expect(reset.walletPence == SaveSnapshot().walletPence)

        // The wipe is persistent, not a one-call filter.
        #expect(!SaveStore(defaults: defaults, resetsOnLaunch: false).load().hasCompletedOfficeCaseIntro)

        defaults.removePersistentDomain(forName: "RainShadow.SaveStoreTests.reset")
    }

    /// The New Game path. `reset()` clears the key rather than writing a blank
    /// snapshot, so a later schema bump starts from `SaveSnapshot()`'s defaults
    /// instead of from today's idea of "empty".
    @Test func resetDiscardsProgressForANewGame() {
        let suite = "RainShadow.SaveStoreTests.newGame"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)

        var snapshot = SaveSnapshot()
        snapshot.hasCompletedOfficeCaseIntro = true
        snapshot.hasSeenOpening = true
        snapshot.inspectedHotspotIDs = ["office.desk", "office.files"]
        snapshot.walletPence = 9
        snapshot.caseFlags = ["metLila"]

        let store = SaveStore(defaults: defaults, resetsOnLaunch: false)
        store.save(snapshot)
        #expect(store.load().hasCompletedOfficeCaseIntro)

        store.reset()

        // Every field returns to its default, not just the one-shot gate.
        let fresh = store.load()
        #expect(!fresh.hasCompletedOfficeCaseIntro)
        #expect(!fresh.hasSeenOpening)
        #expect(fresh.inspectedHotspotIDs.isEmpty)
        #expect(fresh.caseFlags.isEmpty)
        #expect(fresh.walletPence == SaveSnapshot().walletPence)

        // The key is gone, not overwritten with an encoded blank.
        #expect(defaults.data(forKey: "RainShadow.Save.v1") == nil)

        // Resetting an already-empty store is harmless.
        store.reset()
        #expect(!store.load().hasCompletedOfficeCaseIntro)

        defaults.removePersistentDomain(forName: suite)
    }
}
