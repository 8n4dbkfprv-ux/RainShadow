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

    /// Everything a conversation grants must survive a relaunch, not just flags.
    /// Knowledge, evidence, and earned journal fragments used to be merged into the
    /// live session and then dropped by `persist()`, so `hasEvidence` gates silently
    /// regressed on the next launch. The Infinity Engine persists every GLOBAL in the
    /// `.gam` for exactly this reason.
    @Test func persistsEveryDialogueEarnedField() throws {
        let suiteName = "RainShadowTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = SaveStore(defaults: defaults, key: "save")
        let expected = SaveSnapshot(
            caseFlags: ["empty-coat.case.client-retained"],
            caseKnowledgeIDs: ["kn.lila-lied-about-the-tram"],
            caseEvidenceIDs: ["ev.tram-receipt"],
            caseJournalFragments: [
                PersistedJournalFragment(id: "chrono.client-retained", kind: "chronology", text: "Retained.")
            ],
            caseCounters: ["talk.npc.lila-march": 2]
        )

        store.save(expected)
        let loaded = store.load()

        #expect(loaded == expected)
        #expect(loaded.caseKnowledgeIDs.contains("kn.lila-lied-about-the-tram"))
        #expect(loaded.caseEvidenceIDs.contains("ev.tram-receipt"))
        #expect(loaded.caseJournalFragments.first?.id == "chrono.client-retained")
        #expect(loaded.caseCounters["talk.npc.lila-march"] == 2)
    }

    /// A save written before these fields existed still loads — the fields are
    /// additive and optional, which is why the envelope never has to bump.
    @Test func legacySaveWithoutCaseStateFieldsLoadsWithDefaults() throws {
        let suiteName = "RainShadowTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let legacy = Data("""
        {"schemaVersion":1,"hasSeenOpening":true,"caseFlags":["a"],"walletPence":12}
        """.utf8)
        defaults.set(legacy, forKey: "save")

        let loaded = SaveStore(defaults: defaults, key: "save").load()

        #expect(loaded.hasSeenOpening)
        #expect(loaded.caseFlags == ["a"])
        #expect(loaded.walletPence == 12)
        #expect(loaded.caseKnowledgeIDs.isEmpty)
        #expect(loaded.caseEvidenceIDs.isEmpty)
        #expect(loaded.caseJournalFragments.isEmpty)
        #expect(loaded.caseCounters.isEmpty)
    }

    /// `load()` accepts anything at or below the current envelope, so a future
    /// additive bump cannot wipe existing saves. A *newer* snapshot is still
    /// rejected — this binary would drop state it does not understand.
    @Test func acceptsOlderEnvelopesAndRejectsNewerOnes() throws {
        let suiteName = "RainShadowTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = SaveStore(defaults: defaults, key: "save")

        store.save(SaveSnapshot(schemaVersion: 0, hasSeenOpening: true))
        #expect(store.load().hasSeenOpening)

        store.save(SaveSnapshot(
            schemaVersion: SaveSnapshot.currentSchemaVersion + 1,
            hasSeenOpening: true
        ))
        #expect(store.load() == SaveSnapshot())
    }

    @Test func returnsSafeDefaultsForCorruptData() throws {
        let suiteName = "RainShadowTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(Data("not-json".utf8), forKey: "save")

        let store = SaveStore(defaults: defaults, key: "save")

        #expect(store.load() == SaveSnapshot())
    }

    /// Harborpoint PD was renamed Lamp Ward (and its station the Lamphouse)
    /// after saves existed. Area-keyed state written under the old ids must
    /// load under the new ones, and a value already under a new id wins.
    @Test func legacyAreaIDsLoadUnderTheirRenamedIDs() throws {
        let suiteName = "RainShadowTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = SaveStore(defaults: defaults, key: "save")
        let flag = PersistedAreaVariable(kind: "integer", integer: 1)
        let pile = PersistedGroundItemStack(
            id: "matchbook", quantity: 1, isIdentified: true, charges: nil, x: 4, y: 2
        )
        store.save(SaveSnapshot(
            groundPiles: ["city_harborpoint_pd": [pile], "office_suite": []],
            areaVariables: [
                "city_harborpoint_pd/visited": flag,
                "interior_police_station/door.seen": flag,
                "city_sable_row/visited": flag
            ]
        ))

        let loaded = store.load()
        #expect(loaded.groundPiles["city_lamp_ward"] == [pile])
        #expect(loaded.groundPiles["city_harborpoint_pd"] == nil)
        #expect(loaded.groundPiles["office_suite"] == [])
        #expect(loaded.areaVariables["city_lamp_ward/visited"] == flag)
        #expect(loaded.areaVariables["interior_lamphouse/door.seen"] == flag)
        #expect(loaded.areaVariables["city_sable_row/visited"] == flag)
        #expect(loaded.areaVariables["city_harborpoint_pd/visited"] == nil)

        let newer = PersistedAreaVariable(kind: "integer", integer: 2)
        #expect(LegacySaveIDs.rekeyedAreaVariables([
            "city_harborpoint_pd/visited": flag,
            "city_lamp_ward/visited": newer
        ]) == ["city_lamp_ward/visited": newer])
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
