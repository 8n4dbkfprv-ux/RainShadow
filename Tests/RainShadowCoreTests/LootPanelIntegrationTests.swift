import Foundation
import Testing
@testable import RainShadowCore

struct LootPanelIntegrationTests {
    @Test func officeInspectionUsesNonModalPanelAndPersistsBothTransferDirections() throws {
        let source = try read("RainShadow Shared/Scenes/DetectiveOffice/DetectiveOfficeScene.swift")

        #expect(source.contains("private func presentLootContainerPanelIfNeeded"))
        #expect(source.contains("LootContainerPanelEntry(sourceIndex: index, stack: stack)"))
        #expect(source.contains("context.session.takeLootStack(at: sourceIndex, from: containerID)"))
        #expect(source.contains("context.session.takeAllLoot(from: containerID)"))
        #expect(source.contains("context.session.returnCarriedItem(at: acquiredIndex, to: containerID)"))
        #expect(source.contains("case .inventoryFull:"))
        #expect(source.contains("refreshActiveLootContainer(feedback: .bagFull)"))
        #expect(source.contains("sourceArtName: lootSourceArtName(for: hotspot.id)"))
        #expect(source.contains("if dismissLootContainerPanel()"))
        #expect(!source.contains("presentLootInventoryIfNeeded"))
        #expect(!source.contains("onTakeNearby"))

        // The loot strip is non-modal: it is not one of the full-screen windows,
        // so it appears neither in the overlay enum nor in the projection derived
        // from it. Both scenes used to keep their own copy of that state; it now
        // lives once on `BaseGameScene`.
        let base = try read("RainShadow Shared/Core/Scene/BaseGameScene.swift")
        let overlayEnum = try #require(base.range(of: "enum GameOverlay {"))
        let overlayEnumEnd = try #require(
            base.range(of: "\n    }\n", range: overlayEnum.upperBound..<base.endIndex)
        )
        #expect(!base[overlayEnum.lowerBound..<overlayEnumEnd.upperBound].lowercased().contains("loot"))

        let projection = try #require(base.range(of: "var anyOverlayIsPresented: Bool {"))
        let projectionEnd = try #require(
            base.range(of: "\n    }\n", range: projection.upperBound..<base.endIndex)
        )
        #expect(!base[projection.lowerBound..<projectionEnd.upperBound].contains("lootContainerPanel"))
    }

    @Test func inventoryHasOnePersistedSixteenSlotBagAndNoNearbyModel() throws {
        let source = try read("RainShadow Shared/UI/InventoryOverlay.swift")
        // Slot geometry moved to InventoryScreenLayout so it could be tested;
        // see InventoryScreenLayoutTests.
        #expect(InventoryScreenLayout.bagSlotCount == 16)
        #expect(source.contains("inventory_section_bag_v06"))
        #expect(source.contains("func present("))
        #expect(source.contains("inventory: CharacterInventory"))
        #expect(source.contains("InventoryItemPresentation.carriedItems("))
        #expect(source.contains("rebuildBagSlots()"))
        #expect(!source.lowercased().contains("nearby"))
    }

    @Test func compactPanelUsesCorrectFiveZoneTransferHierarchy() throws {
        let source = try read("RainShadow Shared/UI/LootContainerPanelNode.swift")
        #expect(source.contains("hud_loot_container_panel_v02"))
        #expect(source.contains("hud_loot_take_all_v03"))
        #expect(source.contains("onTakeSourceStackAtIndex"))
        #expect(source.contains("onTakeAllLoot"))
        #expect(source.contains("onReturnCarriedStackAtIndex"))
        #expect(source.contains("case source(LootContainerPanelEntry)"))
        #expect(source.contains("case carried(acquiredIndex: Int)"))
        // The starter kit is real carried stacks now, so the panel reads the bag
        // once instead of prepending a second copy of the six painted items.
        #expect(source.contains("InventoryItemPresentation.carriedItems(carriedInventory.stacks"))
        #expect(!source.contains("InventoryItemCatalog"))
        #expect(source.contains("CASE BAG FULL"))
        #expect(!source.contains("ui_close_box"))
        #expect(!source.contains("WALLET"))
    }

    @Test func finalItemKeepsEmptySourceOpenForImmediateReverseTransfer() throws {
        let panel = try read("RainShadow Shared/UI/LootContainerPanelNode.swift")
        let office = try read("RainShadow Shared/Scenes/DetectiveOffice/DetectiveOfficeScene.swift")

        #expect(panel.contains("private(set) var keepsEmptySourceOpenForReverseTransfer = false"))
        #expect(panel.contains("if feedback?.transferredAnyItem == true"))
        #expect(panel.contains("&& !keepsEmptySourceOpenForReverseTransfer"))
        #expect(panel.contains("if !entries.isEmpty, currentLayout.takeAllHitRect.contains(point)"))
        #expect(!panel.contains("guard !entries.isEmpty else { return nil }"))
        #expect(panel.contains("case .item:"))
        #expect(panel.contains("case .coins, .bagFull:"))
        #expect(office.contains(
            "if entries.isEmpty && !lootContainerPanel.keepsEmptySourceOpenForReverseTransfer"
        ))
    }

    @Test func partialTakeAllReportsReceiptAndFullBagTogether() throws {
        let panel = try read("RainShadow Shared/UI/LootContainerPanelNode.swift")
        let office = try read("RainShadow Shared/Scenes/DetectiveOffice/DetectiveOfficeScene.swift")

        #expect(panel.contains("case batch(pence: Int, itemStackCount: Int, bagIsFull: Bool)"))
        #expect(panel.contains("let warning = bagIsFull ? \"CASE BAG FULL\" : nil"))
        #expect(panel.contains("[currency, items, warning]"))
        #expect(office.contains("let hasItemOverflowAtFullCapacity"))
        #expect(office.contains("bagIsFull: hasItemOverflowAtFullCapacity"))
        #expect(office.contains("else if hasItemOverflowAtFullCapacity"))
    }

    @Test func officeAndCityPresentTheSamePersistedCarriedBag() throws {
        let base = try read("RainShadow Shared/Core/Scene/BaseGameScene.swift")
        let office = try read("RainShadow Shared/Scenes/DetectiveOffice/DetectiveOfficeScene.swift")
        let city = try read("RainShadow Shared/Scenes/CityDistrict/CityDistrictScene.swift")

        // One window, filled from committed session state, shared by every scene.
        // The office and the city each kept a private copy of this refresh, which
        // is how the city's came to be missing the encumbrance sync.
        #expect(base.contains("func refreshInventoryOverlay()"))
        #expect(base.contains("inventory: context.session.characterInventory"))
        #expect(!office.contains("func refreshInventoryOverlay()"))
        #expect(!city.contains("func refreshInventoryOverlay()"))

        // Both still push committed state back after a bag mutation rather than
        // letting the window hold its own copy.
        #expect(office.contains("refreshInventoryOverlay()"))
        #expect(city.contains("refreshInventoryOverlay()"))
    }

    @Test func baseSceneOwnsPanelBelowDialogueAndLaysItOutWithHUD() throws {
        let source = try read("RainShadow Shared/Core/Scene/BaseGameScene.swift")
        #expect(source.contains("let lootContainerPanel = LootContainerPanelNode()"))
        #expect(source.contains("lootContainerPanel.layout(for: hudViewportSize)"))
        #expect(source.contains("lootContainerPanel.zPosition = 50"))
        #expect(source.contains("dialoguePresenter.zPosition = 60"))
        #expect(source.contains("hudRoot.addChild(lootContainerPanel)"))
    }

    private func read(_ relativePath: String) throws -> String {
        try String(
            contentsOf: repositoryRoot().appendingPathComponent(relativePath),
            encoding: .utf8
        )
    }

    private func repositoryRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
