import Foundation
import Testing
@testable import RainShadowCore
@testable import RainShadowPersistence

struct CarriedLootTransferTests {
    @Test func sixStarterSlotsLeaveTenAcquiredSlotsInTheCaseBag() {
        var inventory = CarriedInventoryState(reservedSlotCount: 6)

        #expect(inventory.totalSlotCapacity == 16)
        #expect(inventory.itemSlotCapacity == 10)
        #expect(inventory.occupiedSlotCount == 6)
        #expect(inventory.availableSlotCount == 10)

        for index in 0..<10 {
            let appended = inventory.append(CarriedItemStack(id: "item-\(index)", quantity: 1))
            #expect(appended)
        }

        let fullInventory = inventory
        #expect(inventory.isFull)
        let appendedOverflow = inventory.append(CarriedItemStack(id: "overflow", quantity: 1))
        #expect(!appendedOverflow)
        #expect(inventory == fullInventory)
    }

    @Test func firearmStackUsesOneOrdinarySlotAndCanReturnToTheSource() throws {
        let firearm = CarriedItemStack(id: "service-revolver", quantity: 1)
        var inventory = CarriedInventoryState(reservedSlotCount: 6)
        var containers = LootContainerState(resolved: ["office.desk": []])
        let availableBeforePickup = inventory.availableSlotCount

        let appendedToInventory = inventory.append(firearm)
        #expect(appendedToInventory)
        #expect(inventory.availableSlotCount == availableBeforePickup - 1)
        #expect(inventory.occupiedSlotCount == 7)

        let maybeReturned = inventory.takeStack(at: 0)
        let returned = try #require(maybeReturned)
        #expect(returned == firearm)
        let appendedToSource = containers.appendItem(returned, to: "office.desk")
        #expect(appendedToSource)
        #expect(inventory.stacks.isEmpty)
        #expect(containers.contents(of: "office.desk") == [
            .item(id: "service-revolver", quantity: 1)
        ])
    }

    @Test func takeAllCreditsCoinsAndTakesOnlyTheFirstItemsThatFit() throws {
        var containers = LootContainerState(resolved: [
            "office.desk": [
                .item(id: "letter", quantity: 1),
                .coins(pence: 12),
                .item(id: "matches", quantity: 3),
                .coins(pence: 24),
                .item(id: "photograph", quantity: 1)
            ]
        ])

        let maybeResult = containers.takeAll(from: "office.desk", itemSlotCapacity: 2)
        let result = try #require(maybeResult)

        #expect(result.creditedPence == 36)
        #expect(result.itemStacks == [
            CarriedItemStack(id: "letter", quantity: 1),
            CarriedItemStack(id: "matches", quantity: 3)
        ])
        #expect(containers.contents(of: "office.desk") == [
            .item(id: "photograph", quantity: 1)
        ])
    }

    @Test func repeatedTakeAllCannotCreditTheSameCoinsTwice() throws {
        var containers = LootContainerState(resolved: [
            "office.files": [
                .coins(pence: 36),
                .item(id: "ledger", quantity: 1),
                .coins(pence: 6)
            ]
        ])

        let maybeFirst = containers.takeAll(from: "office.files", itemSlotCapacity: 0)
        let first = try #require(maybeFirst)
        let maybeSecond = containers.takeAll(from: "office.files", itemSlotCapacity: 0)
        let second = try #require(maybeSecond)

        #expect(first.creditedPence == 42)
        #expect(second.creditedPence == 0)
        #expect(first.itemStacks.isEmpty)
        #expect(second.itemStacks.isEmpty)
        #expect(containers.contents(of: "office.files") == [
            .item(id: "ledger", quantity: 1)
        ])
    }

    @Test func invalidSourceAndReturnDestinationLeaveStateUntouched() {
        let original = LootContainerState(resolved: [
            "office.desk": [.coins(pence: 12)]
        ])
        var containers = original
        let item = CarriedItemStack(id: "letter", quantity: 1)

        let takeAllResult = containers.takeAll(from: "missing", itemSlotCapacity: 10)
        let appended = containers.appendItem(item, to: "missing")
        #expect(takeAllResult == nil)
        #expect(!appended)
        #expect(containers == original)
    }

    @Test func returnedItemsAppendToTheActiveContainerInOrder() throws {
        var inventory = CarriedInventoryState(
            stacks: [
                CarriedItemStack(id: "letter", quantity: 1),
                CarriedItemStack(id: "matches", quantity: 3)
            ],
            reservedSlotCount: 6
        )
        var containers = LootContainerState(resolved: [
            "office.desk": [.coins(pence: 12)]
        ])

        let maybeReturned = inventory.takeStack(at: 0)
        let returned = try #require(maybeReturned)
        #expect(returned == CarriedItemStack(id: "letter", quantity: 1))
        let appended = containers.appendItem(returned, to: "office.desk")
        #expect(appended)
        #expect(inventory.stacks == [CarriedItemStack(id: "matches", quantity: 3)])
        #expect(containers.contents(of: "office.desk") == [
            .coins(pence: 12),
            .item(id: "letter", quantity: 1)
        ])
    }
}

@MainActor
struct CarriedLootPersistenceTests {
    @Test func acquiredStacksRoundTripWithoutPersistingStarterSlots() throws {
        let suiteName = "RainShadowTests.CarriedLoot.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = SaveStore(defaults: defaults, key: "save")
        let expected = SaveSnapshot(
            carriedItems: [
                PersistedCarriedItemStack(id: "letter", quantity: 1),
                PersistedCarriedItemStack(id: "matches", quantity: 3)
            ]
        )

        store.save(expected)

        #expect(store.load() == expected)
        #expect(store.load().carriedItems.count == 2)
    }

    @Test func firearmStackPersistsThroughTheGenericCarriedItemMirror() throws {
        let suiteName = "RainShadowTests.CarriedFirearm.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = SaveStore(defaults: defaults, key: "save")
        let firearm = PersistedCarriedItemStack(id: "service-revolver", quantity: 1)
        let snapshot = SaveSnapshot(carriedItems: [firearm])

        store.save(snapshot)

        #expect(store.load().carriedItems == [firearm])
    }

    @Test func legacySaveWithoutCarriedItemsDefaultsToEmpty() throws {
        let suiteName = "RainShadowTests.LegacyCarriedLoot.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let legacy: [String: Any] = [
            "schemaVersion": 1,
            "walletPence": 1_800,
            "lootContainers": [:]
        ]
        defaults.set(try JSONSerialization.data(withJSONObject: legacy), forKey: "save")

        let loaded = SaveStore(defaults: defaults, key: "save").load()

        #expect(loaded.walletPence == 1_800)
        #expect(loaded.carriedItems.isEmpty)
    }
}
