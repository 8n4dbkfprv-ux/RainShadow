import Foundation

/// Authored equipment overlays for the current Rustic Voss. These resources
/// share VossCHMF's frame names and registration, but own their palette and pixels.
enum VossWeaponAppearance: String, Sendable {
    case lanternShortsword = "lantern-shortsword"

    case elvenCourtBow = "elven-court-bow"

    var character: String {
        switch self {
        case .lanternShortsword: "VossLanternShortsword"
        case .elvenCourtBow: "VossElvenCourtBow"
        }
    }
    var atlas: String { character + ".atlas" }
    var paperdollArt: String {
        switch self {
        case .lanternShortsword: "voss_paperdoll_lantern_shortsword"
        case .elvenCourtBow: "voss_paperdoll_elven_court_bow"
        }
    }

    static func equipped(in inventory: CharacterInventory, catalog: ItemCatalog) -> Self? {
        inventory.readiedWeapon(catalog: catalog).flatMap { Self(rawValue: $0.id) }
    }

    func frameName(matching body: IEIndexedSprite.FrameID) -> String? {
        guard body.atlas == VossAnimationSet.atlas,
              body.name.hasPrefix("idle_") || body.name.hasPrefix("walk_") else { return nil }
        return body.name
    }

    func validate(_ sprite: IEIndexedSprite) throws {
        guard sprite.character == character,
              (self != .elvenCourtBow || sprite.blobSHA256 == "bd630bdbd7230680d52c9c5b117c74303636e7696c30163ca7bd10ab2372a136"),
              sprite.sourceCanvasSize == .init(width: 128, height: 128),
              sprite.compatibilityDisplaySize == .init(x: 140.625, y: 140.625),
              sprite.frames.count == 1200 else {
            throw IEIndexedSpriteError.malformedManifest(reason: "Incomplete or misregistered Voss weapon overlay")
        }
        for direction in VossAnimationSet.directions {
            for (clip, count) in [("idle", VossAnimationSet.idleFrames), ("walk", VossAnimationSet.walkFrames)] {
                for phase in 0..<count {
                    let name = String(format: "%@_%@_%02d.png", clip, direction, phase)
                    guard sprite.frame(atlas: atlas, name: name) != nil else {
                        throw IEIndexedSpriteError.invalidFrame(atlas: atlas, name: name,
                            reason: "Missing synchronized equipment frame")
                    }
                }
            }
        }
    }
}


/// Independent worn layers; carrying an item never enables its appearance.
enum VossArmorAppearance: String, CaseIterable, Sendable {
    case ironHelmet = "iron-helmet"
    case splintMail = "splint-mail"

    // October 5 promotion of the winged helmet and cupped-shoulder armor.
    var expectedBlobSHA256: String {
        self == .ironHelmet ? "4a2c4d7f89b843574d34ee688b44991965a4de8ea49de94aab6a279f704386b6" : "262f53e5c21b5f6d80dd2813a2272a94e8475f32fee5798401bf42ba12ffe21c"
    }

    var slot: EquipmentSlot { self == .ironHelmet ? .fedora : .coat }
    var character: String { self == .ironHelmet ? "VossIronHelmet" : "VossSplintMail" }
    var atlas: String { character + ".atlas" }
    var paperdollArt: String {
        self == .ironHelmet ? "voss_paperdoll_iron_helmet" : "voss_paperdoll_splint_mail"
    }
    func paperdollArt(wearingMail: Bool) -> String {
        self == .ironHelmet && !wearingMail ? paperdollArt + "_unarmored" : paperdollArt
    }

    func isEquipped(in inventory: CharacterInventory) -> Bool {
        inventory.equipped[slot]?.id == rawValue
    }

    func frameName(matching body: IEIndexedSprite.FrameID, wearingMail: Bool = true) -> String? {
        guard body.atlas == VossAnimationSet.atlas,
              body.name.hasPrefix("idle_") || body.name.hasPrefix("walk_") else { return nil }
        return self == .ironHelmet && !wearingMail ? "unarmored_" + body.name : body.name
    }

    func validate(_ sprite: IEIndexedSprite) throws {
        guard sprite.character == character, sprite.blobSHA256 == expectedBlobSHA256,
              sprite.paletteLayout == .bgeeMixed,
              sprite.sourceCanvasSize == .init(width: 128, height: 128),
              sprite.compatibilityDisplaySize == .init(x: 140.625, y: 140.625),
              sprite.frames.count == (self == .ironHelmet ? 2400 : 1200) else {
            throw IEIndexedSpriteError.malformedManifest(reason: "Incomplete or misregistered Voss armor overlay")
        }
        for direction in VossAnimationSet.directions {
            for (clip, count) in [("idle", VossAnimationSet.idleFrames), ("walk", VossAnimationSet.walkFrames)] {
                for phase in 0..<count {
                    let name = String(format: "%@_%@_%02d.png", clip, direction, phase)
                    if self == .ironHelmet {
                        guard let standalone = sprite.frame(atlas: atlas, name: "unarmored_" + name), !standalone.isEmpty else {
                            throw IEIndexedSpriteError.invalidFrame(atlas: atlas, name: "unarmored_" + name,
                                reason: "Missing helmet frame without armor occlusion")
                        }
                    }
                    guard sprite.frame(atlas: atlas, name: name) != nil else {
                        throw IEIndexedSpriteError.invalidFrame(atlas: atlas, name: name,
                            reason: "Missing synchronized equipment frame")
                    }
                }
            }
        }
    }
}

/// Ammunition occupies a quiver slot; its held appearance requires the matching
/// readied bow. It never bypasses the two-handed weapon's off-hand restriction.
enum VossAmmunitionAppearance: String, Sendable {
    case elvenCourtArrow = "elven-court-arrow"

    var character: String { "VossElvenCourtArrow" }
    var atlas: String { character + ".atlas" }
    var paperdollArt: String { "voss_paperdoll_elven_court_arrow" }

    static func equipped(in inventory: CharacterInventory, catalog: ItemCatalog) -> Self? {
        guard VossWeaponAppearance.equipped(in: inventory, catalog: catalog) == .elvenCourtBow else { return nil }
        return EquipmentSlot.quiverSlots.lazy.compactMap { slot -> Self? in
            guard let stack = inventory.equipped[slot], stack.quantity > 0 else { return nil }
            return stack.id == CombatAmmunition.fireItemID ? .elvenCourtArrow : Self(rawValue: stack.id)
        }.first
    }

    func frameName(matching body: IEIndexedSprite.FrameID) -> String? {
        guard body.atlas == VossAnimationSet.atlas,
              body.name.hasPrefix("idle_") || body.name.hasPrefix("walk_") else { return nil }
        return body.name
    }

    func validate(_ sprite: IEIndexedSprite) throws {
        guard sprite.character == character,
              sprite.blobSHA256 == "de0853e3f748570352faaf03e458cc1f2f03cab2e82fa2028d5fc533a9059329",
              sprite.sourceCanvasSize == .init(width: 128, height: 128),
              sprite.compatibilityDisplaySize == .init(x: 140.625, y: 140.625),
              sprite.frames.count == 1200 else {
            throw IEIndexedSpriteError.malformedManifest(reason: "Incomplete or misregistered Voss ammunition overlay")
        }
        for direction in VossAnimationSet.directions {
            for (clip, count) in [("idle", VossAnimationSet.idleFrames), ("walk", VossAnimationSet.walkFrames)] {
                for phase in 0..<count {
                    let name = String(format: "%@_%@_%02d.png", clip, direction, phase)
                    guard sprite.frame(atlas: atlas, name: name) != nil else {
                        throw IEIndexedSpriteError.invalidFrame(atlas: atlas, name: name,
                            reason: "Missing synchronized equipment frame")
                    }
                }
            }
        }
    }
}
