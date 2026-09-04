import CoreGraphics
import Foundation
import Testing
@testable import RainShadowCore
@testable import RainShadowPersistence

struct GroundPileTests {

    private static func stack(_ id: String, _ quantity: Int = 1) -> CarriedItemStack {
        CarriedItemStack(id: id, quantity: quantity)
    }

    // MARK: - Dropping and taking

    @Test func aDroppedStackStaysWhereItFell() {
        var piles = GroundPileState()
        piles.drop(Self.stack("matchbook"), in: "office", at: CGPoint(x: 40, y: -12))

        let pile = piles.stacks(in: "office")
        #expect(pile.count == 1)
        #expect(pile[0].position == CGPoint(x: 40, y: -12))
        #expect(pile[0].stack.id == "matchbook")
    }

    @Test func pilesAreKeptPerArea() {
        var piles = GroundPileState()
        piles.drop(Self.stack("matchbook"), in: "office", at: .zero)
        piles.drop(Self.stack("brass-key"), in: "sableRow", at: .zero)

        #expect(piles.stacks(in: "office").count == 1)
        #expect(piles.stacks(in: "sableRow").count == 1)
        #expect(piles.stacks(in: "harborpoint-pd").isEmpty)
    }

    @Test func takingRemovesExactlyTheStackThatWasClicked() {
        // Removal is by identity, not index: the quick-loot bar sorts by distance,
        // so an index would take whatever happened to be nearest instead.
        var piles = GroundPileState()
        piles.drop(Self.stack("matchbook"), in: "office", at: CGPoint(x: 100, y: 0))
        piles.drop(Self.stack("brass-key"), in: "office", at: CGPoint(x: 10, y: 0))

        let nearest = piles.stacks(in: "office", near: .zero, radius: 500).first
        let target = try! #require(nearest)
        #expect(target.stack.id == "brass-key")

        let taken = piles.take(target, from: "office")
        #expect(taken?.id == "brass-key")
        #expect(piles.stacks(in: "office").map(\.stack.id) == ["matchbook"])
    }

    @Test func takingSomethingAlreadyGoneChangesNothing() {
        var piles = GroundPileState()
        piles.drop(Self.stack("matchbook"), in: "office", at: .zero)
        let entry = piles.stacks(in: "office")[0]

        #expect(piles.take(entry, from: "office") != nil)
        #expect(piles.take(entry, from: "office") == nil, "a second take finds nothing")
        #expect(piles.stacks(in: "office").isEmpty)
    }

    @Test func anEmptyStackIsNeverDropped() {
        var piles = GroundPileState()
        piles.drop(CarriedItemStack(id: "matchbook", quantity: 0), in: "office", at: .zero)
        #expect(piles.isEmpty)
    }

    // MARK: - Reach

    @Test func onlyWhatIsWithinReachIsOffered() {
        var piles = GroundPileState()
        piles.drop(Self.stack("near"), in: "office", at: CGPoint(x: 50, y: 0))
        piles.drop(Self.stack("far"), in: "office", at: CGPoint(x: 5_000, y: 0))

        let reachable = piles.stacks(in: "office", near: .zero, radius: 420)
        #expect(reachable.map(\.stack.id) == ["near"])
    }

    @Test func nearbyStacksComeBackNearestFirst() {
        var piles = GroundPileState()
        piles.drop(Self.stack("c"), in: "office", at: CGPoint(x: 300, y: 0))
        piles.drop(Self.stack("a"), in: "office", at: CGPoint(x: 10, y: 0))
        piles.drop(Self.stack("b"), in: "office", at: CGPoint(x: 100, y: 0))

        let sorted = piles.stacks(in: "office", near: .zero, radius: 420)
        #expect(sorted.map(\.stack.id) == ["a", "b", "c"])
    }

    // MARK: - Paging

    @Test func aSingleRowNeedsNoArrows() {
        let page = QuickLootPage(itemCount: 10, requestedPage: 0)
        #expect(!page.needsPaging)
        #expect(page.pageCount == 1)
        #expect(page.range == 0..<10)
    }

    @Test func pastOneRowTheArrowsAppear() {
        // BG:EE: "If there are more than ten items, scroll buttons appear."
        let page = QuickLootPage(itemCount: 11, requestedPage: 0)
        #expect(page.needsPaging)
        #expect(page.pageCount == 2)
        #expect(page.range == 0..<10)

        let second = QuickLootPage(itemCount: 11, requestedPage: 1)
        #expect(second.range == 10..<11)
    }

    @Test func pagingClampsRatherThanTrappingOnAStalePage() {
        // Taking the last item on page two must not leave the bar reading past
        // the end of the pile.
        let page = QuickLootPage(itemCount: 4, requestedPage: 9)
        #expect(page.pageIndex == 0)
        #expect(page.range == 0..<4)

        let negative = QuickLootPage(itemCount: 4, requestedPage: -3)
        #expect(negative.pageIndex == 0)
    }

    @Test func anEmptyPileStillProducesAValidPage() {
        let page = QuickLootPage(itemCount: 0, requestedPage: 0)
        #expect(page.pageCount == 1)
        #expect(page.range.isEmpty)
        #expect(!page.needsPaging)
    }

    // MARK: - Bar geometry

    @Test func theBarStaysBetweenTheHUDRails() {
        let size = CGSize(width: 1_280, height: 720)
        let layout = HUDChromeLayout.quickLootBarLayout(for: size, showsPaging: true)
        let leftLimit = -size.width / 2 + HUDChromeLayout.leftRailClearance(for: size)
        let rightLimit = size.width / 2 - HUDChromeLayout.rightRailClearance(for: size)

        #expect(layout.panelRect.minX >= leftLimit - 0.5)
        #expect(layout.panelRect.maxX <= rightLimit + 0.5)
        #expect(layout.panelRect.minY >= -size.height / 2)
    }

    @Test func everySlotGetsATouchTargetOfAtLeastFortyFourPoints() {
        // GDD §13 accessibility floor, the same one the container strip honours.
        let layout = HUDChromeLayout.quickLootBarLayout(
            for: CGSize(width: 1_280, height: 720),
            showsPaging: true
        )
        #expect(layout.slotHitRects.count == QuickLootPage.slotsPerPage)
        for rect in layout.slotHitRects {
            #expect(rect.width >= 44)
            #expect(rect.height >= 44)
        }
        #expect(layout.previousArrowHitRect.width >= 44)
        #expect(layout.nextArrowHitRect.width >= 44)
    }

    @Test func arrowsTakeNoRoomWhenThereIsNothingToPage() {
        let paged = HUDChromeLayout.quickLootBarLayout(
            for: CGSize(width: 1_280, height: 720),
            showsPaging: true
        )
        let unpaged = HUDChromeLayout.quickLootBarLayout(
            for: CGSize(width: 1_280, height: 720),
            showsPaging: false
        )
        #expect(unpaged.previousArrowArtRect.width == 0)
        #expect(unpaged.nextArrowArtRect.width == 0)
        #expect(!unpaged.showsPaging)
        // Reclaiming the arrow lane makes each slot wider.
        #expect(unpaged.slotArtRects[0].width >= paged.slotArtRects[0].width)
    }

    @Test func theBarSurvivesACrampedViewport() {
        let layout = HUDChromeLayout.quickLootBarLayout(
            for: CGSize(width: 844, height: 390),
            showsPaging: true
        )
        #expect(layout.panelRect.width > 0)
        #expect(layout.slotArtRects.count == QuickLootPage.slotsPerPage)
        #expect(layout.slotArtRects.allSatisfy { $0.width > 0 })
    }

    // MARK: - Persistence

    @Test func groundPilesSurviveASaveRoundTrip() throws {
        let snapshot = SaveSnapshot(
            groundPiles: [
                "office": [
                    PersistedGroundItemStack(
                        id: "matchbook", quantity: 2, isIdentified: false, x: 12.5, y: -3.25
                    )
                ]
            ]
        )
        let data = try JSONEncoder().encode(snapshot)
        let restored = try JSONDecoder().decode(SaveSnapshot.self, from: data)

        let pile = try #require(restored.groundPiles["office"])
        #expect(pile.count == 1)
        #expect(pile[0].id == "matchbook")
        #expect(pile[0].quantity == 2)
        #expect(!pile[0].isIdentified)
        #expect(pile[0].x == 12.5)
        #expect(pile[0].y == -3.25)
    }

    @Test func aSaveWrittenBeforeGroundPilesExistedStillLoads() throws {
        let legacy = #"{"schemaVersion": 1, "walletPence": 1728}"#
        let restored = try JSONDecoder().decode(SaveSnapshot.self, from: Data(legacy.utf8))
        #expect(restored.groundPiles.isEmpty)
        #expect(restored.walletPence == 1_728)
    }
}
