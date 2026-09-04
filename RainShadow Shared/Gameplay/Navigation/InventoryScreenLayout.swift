import CoreGraphics

/// Geometry for the full-screen inventory window.
///
/// This used to be a private `Metrics` enum inside `InventoryOverlay`, which put
/// the one part of the screen most likely to drift — where the slots are — in the
/// one place the test target cannot reach. The loot strip already solved this by
/// keeping its geometry in `HUDChromeLayout`; this is the same move for the
/// window, and it is what lets slot positions be asserted instead of eyeballed.
///
/// Every constant is a point offset inside the painted 1960×1080 frame. The frame
/// itself is generated offline by `ArtSource/Processing/process_ui_chrome_v05_inventory.py`,
/// so these numbers are hand-matched to baked pixels and must move together with it.
enum InventoryScreenLayout {
    // MARK: - Canvas and chrome

    static let canvas = CGSize(width: 1_960, height: 1_080)

    static let titleY: CGFloat = 520
    static let identityBand = CGPoint(x: 0, y: 390)
    /// Matched by hand to the close box baked into `inventory_outer_frame_v16.png`.
    static let closeButton = CGPoint(x: -957, y: 520)
    static let closeArtworkSize = CGSize(width: 20, height: 20)

    /// One shared content rectangle inside the outer frame's inner rails. The
    /// remaining 280pt of canvas width is painted rail.
    static let contentLeft: CGFloat = -840
    static let contentRight: CGFloat = 840
    static let contentWidth = contentRight - contentLeft
    static let sectionGap: CGFloat = 25

    static let primaryY: CGFloat = 90

    // MARK: - Loadout column (left)

    static let loadoutSize = CGSize(width: 460, height: 520)
    static let loadoutOrigin = CGPoint(
        x: contentLeft + loadoutSize.width / 2,
        y: primaryY
    )
    static let loadoutSlotLeft: CGFloat = -168
    static let loadoutSlotSize: CGFloat = 92
    static let loadoutSlotPitch: CGFloat = 108

    /// The three authored loadout rows, top to bottom.
    enum LoadoutRow: CaseIterable {
        case readyWeapons
        case quickItems
        case coatPockets

        var title: String {
            switch self {
            case .readyWeapons: "READY WEAPONS"
            case .quickItems: "QUICK ITEMS"
            case .coatPockets: "COAT POCKETS"
            }
        }

        var headerY: CGFloat {
            switch self {
            case .readyWeapons: 200
            case .quickItems: 55
            case .coatPockets: -110
            }
        }

        var slotY: CGFloat {
            switch self {
            case .readyWeapons: 144
            case .quickItems: -5
            case .coatPockets: -180
            }
        }

        /// Coat pockets hold ammunition the way BG's quivers do.
        var slots: [EquipmentSlot] {
            switch self {
            case .readyWeapons: EquipmentSlot.weaponSlots
            case .quickItems: EquipmentSlot.quickItemSlots
            case .coatPockets: EquipmentSlot.quiverSlots
            }
        }

        var emptySilhouetteArtName: String {
            switch self {
            case .readyWeapons: "inventory_slot_silhouette_weapon_v06"
            case .quickItems, .coatPockets: "inventory_slot_silhouette_item_v06"
            }
        }
    }

    /// Slot position within the loadout panel's local space.
    static func loadoutSlotPosition(row: LoadoutRow, index: Int) -> CGPoint {
        CGPoint(
            x: loadoutSlotLeft + CGFloat(index) * loadoutSlotPitch,
            y: row.slotY
        )
    }

    // MARK: - Paperdoll column (centre)

    static let paperdollSize = CGSize(width: 520, height: 520)
    static let paperdollOrigin = CGPoint(
        x: contentLeft + loadoutSize.width + sectionGap + paperdollSize.width / 2,
        y: primaryY
    )
    static let paperdollBodySize = CGSize(width: 220, height: 315)
    static let chamberOffset = CGPoint(x: 0, y: -8)
    static let equipSlotSize = CGSize(width: 72, height: 68)
    static let equipIconSize = CGSize(width: 52, height: 48)

    /// BG:EE Classic geometry. Classic hangs four slots in a bar across the top,
    /// shifted left so the doll's head sits under the gap after the last one; the
    /// off-hand rides the right rail at chest height with a ring below it and its
    /// twin mirrored on the left rail; and cloak · boots · belt run as a second bar
    /// under the feet, sharing the top bar's three right-hand columns.
    static let equipColumnPitch: CGFloat = 78
    static let equipColumn4: CGFloat = 53
    static let equipColumn3 = equipColumn4 - equipColumnPitch
    static let equipColumn2 = equipColumn4 - 2 * equipColumnPitch
    static let equipColumn1 = equipColumn4 - 3 * equipColumnPitch
    static let equipTopY: CGFloat = 196
    static let equipBottomY: CGFloat = -196
    static let equipSideX: CGFloat = 195

    /// Slot position within the paperdoll panel's local space. `nil` for slots the
    /// paperdoll does not paint — those live in the loadout column.
    static func paperdollSlotPosition(_ slot: EquipmentSlot) -> CGPoint? {
        switch slot {
        case .coat: CGPoint(x: equipColumn1, y: equipTopY)
        case .gloves: CGPoint(x: equipColumn2, y: equipTopY)
        case .fedora: CGPoint(x: equipColumn3, y: equipTopY)
        case .charm: CGPoint(x: equipColumn4, y: equipTopY)
        case .holster: CGPoint(x: equipSideX, y: -18)
        case .ringLeft: CGPoint(x: -equipSideX, y: -102)
        case .ringRight: CGPoint(x: equipSideX, y: -102)
        case .cloak: CGPoint(x: equipColumn2, y: equipBottomY)
        case .shoes: CGPoint(x: equipColumn3, y: equipBottomY)
        case .belt: CGPoint(x: equipColumn4, y: equipBottomY)
        default: nil
        }
    }

    /// The painted empty-slot silhouette for a slot.
    static func emptySilhouetteArtName(for slot: EquipmentSlot) -> String {
        switch slot {
        case .coat: "inventory_slot_silhouette_coat_v06"
        case .gloves: "inventory_slot_silhouette_hands_v06"
        case .fedora: "inventory_slot_silhouette_hat_v06"
        case .charm: "inventory_slot_silhouette_charm_v06"
        case .holster: "inventory_slot_silhouette_holster_v06"
        case .ringLeft, .ringRight: "inventory_slot_silhouette_ring_v06"
        case .cloak: "inventory_slot_silhouette_cloak_v06"
        case .shoes: "inventory_slot_silhouette_feet_v06"
        case .belt: "inventory_slot_silhouette_belt_v06"
        case .weapon1, .weapon2, .weapon3, .weapon4:
            "inventory_slot_silhouette_weapon_v06"
        case .quiver1, .quiver2, .quiver3,
             .quickItem1, .quickItem2, .quickItem3:
            "inventory_slot_silhouette_item_v06"
        }
    }

    // MARK: - Stats column (right)

    static let statsSize = CGSize(width: 650, height: 560)
    static let statsOrigin = CGPoint(x: contentRight - statsSize.width / 2, y: primaryY)
    static let statRowPitch: CGFloat = 116
    static let statRowTopY: CGFloat = 195
    static let statBadgeSize: CGFloat = 84
    static let statTextWidth: CGFloat = 490
    static var statBadgeX: CGFloat { -statsSize.width / 2 + 62 }

    static func statRowY(index: Int) -> CGFloat {
        statRowTopY - CGFloat(index) * statRowPitch
    }

    // MARK: - Mid description strip

    static let midStripY: CGFloat = -225
    static let midSize = CGSize(width: contentWidth, height: 80)
    static let midDescOrigin = CGPoint(x: 0, y: midStripY)
    static let midPausedOrigin = CGPoint(x: -790, y: midStripY)
    static let midCoinsOrigin = CGPoint(x: 750, y: midStripY)
    /// Weight readout sits between the description and the purse.
    static let midWeightOrigin = CGPoint(x: 430, y: midStripY)

    // MARK: - Case bag

    static let lowerY: CGFloat = -365
    static let bagSize = CGSize(width: 1_680, height: 190)
    static let bagOrigin = CGPoint(x: 0, y: lowerY)
    static let bagSlotCount = 16
    static let bagSlotSize: CGFloat = 70
    static let bagSlotPitch: CGFloat = 84
    static let bagFirstSlotX: CGFloat = -560
    static let bagSlotY: CGFloat = -20
    static let bagArtOffset = CGPoint(x: -750, y: 0)

    /// Slot position within the bag panel's local space.
    static func bagSlotPosition(index: Int) -> CGPoint {
        CGPoint(
            x: bagFirstSlotX + CGFloat(index) * bagSlotPitch,
            y: bagSlotY
        )
    }

    // MARK: - Content-space rectangles

    /// Where a paperdoll slot lands in the window's shared content space, which is
    /// the space hit-testing and collision checks care about.
    static func contentRect(forPaperdoll slot: EquipmentSlot) -> CGRect? {
        guard let local = paperdollSlotPosition(slot) else { return nil }
        return rect(
            centeredAt: CGPoint(
                x: paperdollOrigin.x + local.x,
                y: paperdollOrigin.y + local.y
            ),
            size: equipSlotSize
        )
    }

    static func contentRect(forLoadoutRow row: LoadoutRow, index: Int) -> CGRect {
        let local = loadoutSlotPosition(row: row, index: index)
        return rect(
            centeredAt: CGPoint(
                x: loadoutOrigin.x + local.x,
                y: loadoutOrigin.y + local.y
            ),
            size: CGSize(width: loadoutSlotSize, height: loadoutSlotSize)
        )
    }

    static func contentRect(forBagSlot index: Int) -> CGRect {
        let local = bagSlotPosition(index: index)
        return rect(
            centeredAt: CGPoint(x: bagOrigin.x + local.x, y: bagOrigin.y + local.y),
            size: CGSize(width: bagSlotSize, height: bagSlotSize)
        )
    }

    /// Every interactive slot rect in content space, keyed by its node name.
    /// Used by the overlap test — two slots sharing pixels would make one of them
    /// unclickable, and nothing else would report it.
    static func allSlotRects() -> [(name: String, rect: CGRect)] {
        var rects: [(String, CGRect)] = []
        for slot in EquipmentSlot.paperdollSlots {
            if let rect = contentRect(forPaperdoll: slot) {
                rects.append((slot.nodeName, rect))
            }
        }
        for row in LoadoutRow.allCases {
            for (index, slot) in row.slots.enumerated() {
                rects.append((slot.nodeName, contentRect(forLoadoutRow: row, index: index)))
            }
        }
        for index in 0..<bagSlotCount {
            rects.append(("inventory.bag.\(index)", contentRect(forBagSlot: index)))
        }
        return rects
    }

    private static func rect(centeredAt center: CGPoint, size: CGSize) -> CGRect {
        CGRect(
            x: center.x - size.width / 2,
            y: center.y - size.height / 2,
            width: size.width,
            height: size.height
        )
    }

    // MARK: - Fit

    /// Uniform downscale to fit the viewport. Never scales above 1 — the painted
    /// frame has no more resolution to give.
    static func scale(for visibleSize: CGSize) -> CGFloat {
        let horizontalFit = (visibleSize.width - 34) / canvas.width
        let verticalFit = (visibleSize.height - 30) / canvas.height
        return min(1, horizontalFit, verticalFit)
    }
}
