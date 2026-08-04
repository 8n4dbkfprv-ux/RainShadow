import Foundation
import Testing
@testable import RainShadowCore
@testable import RainShadowPersistence

struct LootSystemTests {
    @Test func currencyFormatsPoundsShillingsPence() {
        #expect(CurrencyAmount(pence: CurrencyAmount.startingWalletPence).formatted == "£7 4s")
        #expect(CurrencyAmount(pounds: 1).formatted == "£1")
        #expect(CurrencyAmount(shillings: 3).formatted == "3s")
        #expect(CurrencyAmount(pence: 5).formatted == "5d")
        #expect(CurrencyAmount(pounds: 1, shillings: 1, pence: 1).formatted == "£1 1s 1d")
        #expect(CurrencyAmount(pence: 0).formatted == "0d")
    }

    @Test func currencyAdditionCreditsPence() {
        var wallet = CurrencyAmount(pence: 100)
        wallet += CurrencyAmount(pence: 36)
        #expect(wallet.pence == 136)
        #expect((CurrencyAmount(pence: 12) + CurrencyAmount(pence: 12)).formatted == "2s")
    }

    @Test func randomCoinTableRollOfOneYieldsNothing() {
        let table = RandomCoinTable(penceForRolls2to20: Array(repeating: 12, count: 19))
        #expect(table.result(forDieRoll: 1) == nil)
        #expect(table.result(forDieRoll: 2) == 12)
        #expect(table.result(forDieRoll: 20) == 12)
        #expect(table.result(forDieRoll: 0) == nil)
        #expect(table.result(forDieRoll: 21) == nil)
    }

    @Test func resolverIsDeterministicWithSeededRNG() {
        let definition = LootContainerDefinition(
            id: "test.crate",
            entries: [
                .coins(pence: 36),
                .randomCoins(table: RandomCoinTable(penceForRolls2to20: Array(1...19).map { $0 })),
                .item(id: "brass-key", quantity: 1)
            ]
        )

        var rngA = SeededGenerator(seed: 42)
        var rngB = SeededGenerator(seed: 42)
        let a = LootResolver.resolve(definition, using: &rngA)
        let b = LootResolver.resolve(definition, using: &rngB)
        #expect(a == b)
        #expect(a.first == .coins(pence: 36))
        #expect(a.last == .item(id: "brass-key", quantity: 1))
    }

    @Test func resolveOnceDoesNotReroll() {
        let definition = LootContainerDefinition(
            id: "office.desk",
            entries: [
                .randomCoins(table: RandomCoinTable(penceForRolls2to20: Array(repeating: 24, count: 19)))
            ]
        )
        var state = LootContainerState()
        var rng = SeededGenerator(seed: 7)
        state.resolveIfNeeded(definition: definition, using: &rng)
        let first = state.contents(of: "office.desk")
        var otherRNG = SeededGenerator(seed: 99)
        state.resolveIfNeeded(definition: definition, using: &otherRNG)
        #expect(state.contents(of: "office.desk") == first)
    }

    @Test func takingCoinStackRemovesItFromContainer() {
        var state = LootContainerState(resolved: [
            "office.desk": [
                .coins(pence: 36),
                .coins(pence: 12),
                .item(id: "matchbook", quantity: 1)
            ]
        ])
        let taken = state.takeStack(at: 1, from: "office.desk")
        #expect(taken == .coins(pence: 12))
        #expect(state.contents(of: "office.desk") == [
            .coins(pence: 36),
            .item(id: "matchbook", quantity: 1)
        ])
        #expect(state.takeStack(at: 9, from: "office.desk") == nil)
    }

    @Test func officeLootCatalogCoversDeskAndFiles() {
        let ids = Set(OfficeNavigationLayout.lootContainers.map(\.id))
        #expect(ids.contains("office.desk"))
        #expect(ids.contains("office.files"))
        #expect(OfficeNavigationLayout.lootContainer(for: "office.desk") != nil)
        #expect(OfficeNavigationLayout.lootContainer(for: "office.window") == nil)
    }
}

@MainActor
struct LootPersistenceTests {
    @Test func saveSnapshotRoundTripsWalletAndLoot() throws {
        let suiteName = "RainShadowTests.Loot.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = SaveStore(defaults: defaults, key: "save")
        let expected = SaveSnapshot(
            hasSeenOpening: true,
            hasSeenOfficeHint: false,
            inspectedHotspotIDs: ["office.desk"],
            walletPence: 1_800,
            lootContainers: [
                "office.desk": [.coins(pence: 36), .item(id: "brass-key", quantity: 1)],
                "office.files": [.coins(pence: 6)]
            ]
        )

        store.save(expected)
        #expect(store.load() == expected)
    }

    @Test func legacySnapshotWithoutLootKeysGetsWalletDefault() throws {
        let suiteName = "RainShadowTests.LootLegacy.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let legacy: [String: Any] = [
            "schemaVersion": 1,
            "hasSeenOpening": true,
            "hasSeenOfficeHint": true,
            "inspectedHotspotIDs": ["office.window"]
        ]
        let data = try JSONSerialization.data(withJSONObject: legacy)
        defaults.set(data, forKey: "save")

        let store = SaveStore(defaults: defaults, key: "save")
        let loaded = store.load()
        #expect(loaded.hasSeenOpening)
        #expect(loaded.walletPence == 1_728)
        #expect(loaded.lootContainers.isEmpty)
        #expect(loaded.inspectedHotspotIDs == ["office.window"])
    }
}

/// Deterministic RNG for loot-resolution tests.
private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0xDEAD_BEEF : seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
