import Foundation
import Testing
@testable import RainShadowCore
@testable import RainShadowPersistence

@MainActor
struct InventoryPersistenceTests {

    // MARK: - Additive schema

    @Test func equippedItemsAndTheStarterSeedRoundTrip() throws {
        let snapshot = SaveSnapshot(
            carriedItems: [PersistedCarriedItemStack(id: "matchbook", quantity: 3)],
            equippedItems: [
                "coat": PersistedCarriedItemStack(id: "trench-coat", quantity: 1),
                "weapon1": PersistedCarriedItemStack(id: "service-revolver", quantity: 1)
            ],
            hasSeededStarterKit: true
        )
        let data = try JSONEncoder().encode(snapshot)
        let restored = try JSONDecoder().decode(SaveSnapshot.self, from: data)

        #expect(restored == snapshot)
        #expect(restored.equippedItems["coat"]?.id == "trench-coat")
        #expect(restored.hasSeededStarterKit)
    }

    @Test func aSaveWrittenBeforeEquipmentExistedStillLoads() throws {
        // The exact shape a pre-equipment binary wrote: no equippedItems key, no
        // hasSeededStarterKit, and carried stacks with neither identification nor
        // charges. It must load, not fail, and not lose the wallet.
        let legacy = """
        {
          "schemaVersion": 1,
          "walletPence": 1728,
          "carriedItems": [{"id": "matchbook", "quantity": 2}]
        }
        """
        let restored = try JSONDecoder().decode(SaveSnapshot.self, from: Data(legacy.utf8))

        #expect(restored.walletPence == 1_728)
        #expect(restored.equippedItems.isEmpty)
        #expect(!restored.hasSeededStarterKit, "an old save has not been seeded yet")
        #expect(restored.carriedItems.count == 1)
        #expect(
            restored.carriedItems[0].isIdentified,
            "a stack written before identification existed was identified"
        )
        #expect(restored.carriedItems[0].charges == nil)
    }

    @Test func identificationAndChargesSurviveTheMirror() throws {
        let stack = PersistedCarriedItemStack(
            id: "matchbook", quantity: 4, isIdentified: false, charges: 2
        )
        let data = try JSONEncoder().encode(stack)
        let restored = try JSONDecoder().decode(PersistedCarriedItemStack.self, from: data)
        #expect(restored == stack)
        #expect(!restored.isIdentified)
        #expect(restored.charges == 2)
    }

    @Test func schemaVersionDoesNotBumpForAdditiveFields() {
        // SaveStore's documented policy: every field added since v1 is additive
        // and optional, so shipped saves stay at 1 and load byte-identically.
        #expect(SaveSnapshot.currentSchemaVersion == 1)
    }

    // MARK: - Round trip through the store

    @Test func theStoreKeepsEquipmentAcrossARelaunch() throws {
        let suite = "RainShadowTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        let store = SaveStore(defaults: defaults)
        store.save(SaveSnapshot(
            carriedItems: [PersistedCarriedItemStack(id: "brass-key", quantity: 1)],
            equippedItems: ["fedora": PersistedCarriedItemStack(id: "fedora", quantity: 1)],
            hasSeededStarterKit: true
        ))

        // A fresh store over the same defaults is what a relaunch looks like.
        let reloaded = SaveStore(defaults: defaults).load()
        #expect(reloaded.equippedItems["fedora"]?.id == "fedora")
        #expect(reloaded.carriedItems.first?.id == "brass-key")
        #expect(reloaded.hasSeededStarterKit)
    }

    // MARK: - Slot keys

    @Test func everySlotRawValueSurvivesADictionaryKeyRoundTrip() throws {
        // Persistence stores the slot as a raw string because it has no Core
        // dependency. A slot whose raw value did not round-trip would silently
        // drop the item it held on the next load.
        for slot in EquipmentSlot.allCases {
            #expect(EquipmentSlot(rawValue: slot.rawValue) == slot)
        }
    }

    @Test func anUnknownSlotKeyIsDroppedRatherThanFailingTheLoad() throws {
        let snapshot = SaveSnapshot(
            equippedItems: ["monocle": PersistedCarriedItemStack(id: "x", quantity: 1)]
        )
        let data = try JSONEncoder().encode(snapshot)
        let restored = try JSONDecoder().decode(SaveSnapshot.self, from: data)
        // The snapshot keeps the raw key; GameSession is what discards it, so the
        // save itself must never reject the unknown slot.
        #expect(restored.equippedItems["monocle"] != nil)
        #expect(EquipmentSlot(rawValue: "monocle") == nil)
    }
}
