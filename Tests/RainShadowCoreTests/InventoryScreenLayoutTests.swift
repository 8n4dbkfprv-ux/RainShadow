import CoreGraphics
import Foundation
import Testing
@testable import RainShadowCore

struct InventoryScreenLayoutTests {

    // MARK: - Frame

    @Test func theCanvasMatchesThePaintedFrame() {
        // inventory_outer_frame_v16.png is generated at 1960×1080 by
        // ArtSource/Processing/process_ui_chrome_v05_inventory.py. If these drift
        // apart, every slot below is measured against the wrong picture.
        #expect(InventoryScreenLayout.canvas == CGSize(width: 1_960, height: 1_080))
        #expect(InventoryScreenLayout.contentWidth == 1_680)
    }

    @Test func theWindowNeverScalesAboveOne() {
        // The painted frame has no more resolution to give.
        #expect(InventoryScreenLayout.scale(for: CGSize(width: 4_000, height: 3_000)) == 1)

        let fit = InventoryScreenLayout.scale(for: CGSize(width: 1_280, height: 720))
        #expect(abs(fit - (1_246.0 / 1_960.0)) < 0.0001, "width is the binding constraint at 720p")
        #expect(fit < 1)
    }

    @Test func aCrampedViewportStillProducesAUsableScale() {
        // The smallest capture size in Documentation/Captures.
        let fit = InventoryScreenLayout.scale(for: CGSize(width: 844, height: 390))
        #expect(fit > 0)
        #expect(fit < 1)
    }

    // MARK: - BG:EE Classic equipped geometry

    @Test func theEquippedBarKeepsItsClassicColumns() {
        // These are the constants commit 7a9efeb3 derived; the paperdoll art is
        // hand-matched to them, so a change here is a change to the picture.
        #expect(InventoryScreenLayout.equipColumnPitch == 78)
        #expect(InventoryScreenLayout.equipColumn4 == 53)
        #expect(InventoryScreenLayout.equipColumn3 == -25)
        #expect(InventoryScreenLayout.equipColumn2 == -103)
        #expect(InventoryScreenLayout.equipColumn1 == -181)
        #expect(InventoryScreenLayout.equipTopY == 196)
        #expect(InventoryScreenLayout.equipBottomY == -196)
        #expect(InventoryScreenLayout.equipSideX == 195)
    }

    @Test func everyPaperdollSlotSitsWhereTheArtPaintsIt() {
        let expected: [EquipmentSlot: CGPoint] = [
            .coat: CGPoint(x: -181, y: 196),
            .gloves: CGPoint(x: -103, y: 196),
            .fedora: CGPoint(x: -25, y: 196),
            .charm: CGPoint(x: 53, y: 196),
            .holster: CGPoint(x: 195, y: -18),
            .ringLeft: CGPoint(x: -195, y: -102),
            .ringRight: CGPoint(x: 195, y: -102),
            .cloak: CGPoint(x: -103, y: -196),
            .shoes: CGPoint(x: -25, y: -196),
            .belt: CGPoint(x: 53, y: -196)
        ]
        for (slot, point) in expected {
            #expect(
                InventoryScreenLayout.paperdollSlotPosition(slot) == point,
                "\(slot.rawValue) moved"
            )
        }
    }

    @Test func onlyThePaperdollSlotsHaveAPaperdollPosition() {
        for slot in EquipmentSlot.allCases {
            let painted = InventoryScreenLayout.paperdollSlotPosition(slot) != nil
            #expect(
                painted == slot.isWorn,
                "\(slot.rawValue) is \(slot.isWorn ? "worn" : "not worn") but \(painted ? "has" : "has no") paperdoll position"
            )
        }
    }

    @Test func everySlotHasAPaintedEmptySilhouette() {
        for slot in EquipmentSlot.allCases {
            let art = InventoryScreenLayout.emptySilhouetteArtName(for: slot)
            #expect(art.hasPrefix("inventory_slot_silhouette_"))
            #expect(art.hasSuffix("_v06"))
        }
    }

    // MARK: - Loadout column

    @Test func theLoadoutRowsCoverTheLoadoutSlots() {
        let rowSlots = InventoryScreenLayout.LoadoutRow.allCases.flatMap(\.slots)
        let expected = EquipmentSlot.weaponSlots
            + EquipmentSlot.quickItemSlots
            + EquipmentSlot.quiverSlots
        #expect(Set(rowSlots) == Set(expected))
        #expect(rowSlots.count == expected.count, "no slot appears in two rows")

        // Between them, the paperdoll and the loadout paint every shipped slot.
        let painted = Set(rowSlots).union(EquipmentSlot.paperdollSlots)
        #expect(painted == Set(EquipmentSlot.allCases))
    }

    @Test func loadoutRowsShareTheirLeftEdge() {
        for row in InventoryScreenLayout.LoadoutRow.allCases {
            let first = InventoryScreenLayout.loadoutSlotPosition(row: row, index: 0)
            #expect(first.x == InventoryScreenLayout.loadoutSlotLeft)
            #expect(first.y == row.slotY)
        }
    }

    @Test func coatPocketsHoldAmmunition() {
        // The row is named for a coat, but it is BG's quiver bank.
        #expect(InventoryScreenLayout.LoadoutRow.coatPockets.slots == EquipmentSlot.quiverSlots)
        #expect(EquipmentSlot.quiver1.accepts(.ammunition))
    }

    // MARK: - Case bag

    @Test func theBagPaintsSixteenSlotsInOneRow() {
        #expect(InventoryScreenLayout.bagSlotCount == 16)
        let first = InventoryScreenLayout.bagSlotPosition(index: 0)
        let last = InventoryScreenLayout.bagSlotPosition(index: 15)
        #expect(first.y == last.y, "the case bag is a single row")
        #expect(first.x == InventoryScreenLayout.bagFirstSlotX)
        #expect(last.x == InventoryScreenLayout.bagFirstSlotX + 15 * InventoryScreenLayout.bagSlotPitch)
    }

    // MARK: - The invariant that matters

    @Test func noTwoSlotsShareAnyPixels() {
        // An overlap makes one of the two slots unclickable, and nothing else in
        // the build would report it — the window is painted art plus hit tests.
        let rects = InventoryScreenLayout.allSlotRects()
        for i in rects.indices {
            for j in rects.indices where j > i {
                #expect(
                    !rects[i].rect.intersects(rects[j].rect),
                    "\(rects[i].name) overlaps \(rects[j].name)"
                )
            }
        }
    }

    @Test func everySlotStaysInsideTheContentRails() {
        // Outside the rails a slot is drawn over painted frame, where it reads as
        // a rendering bug rather than a target.
        for entry in InventoryScreenLayout.allSlotRects() {
            #expect(
                entry.rect.minX >= InventoryScreenLayout.contentLeft,
                "\(entry.name) runs off the left rail"
            )
            #expect(
                entry.rect.maxX <= InventoryScreenLayout.contentRight,
                "\(entry.name) runs off the right rail"
            )
        }
    }

    @Test func everySlotNameIsUnique() {
        let names = InventoryScreenLayout.allSlotRects().map(\.name)
        #expect(Set(names).count == names.count)
        #expect(names.count == 10 + 10 + 16, "ten worn, ten loadout, sixteen bag")
    }
}
