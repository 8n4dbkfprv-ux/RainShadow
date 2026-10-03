import Foundation

/// Authored equipment overlays for the current Rustic Voss. These resources
/// share VossCHMF's frame names and registration, but own their palette and pixels.
enum VossWeaponAppearance: String, Sendable {
    case lanternShortsword = "lantern-shortsword"

    var character: String { "VossLanternShortsword" }
    var atlas: String { "VossLanternShortsword.atlas" }
    var paperdollArt: String { "voss_paperdoll_lantern_shortsword" }

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

    var slot: EquipmentSlot { self == .ironHelmet ? .fedora : .coat }
    var character: String { self == .ironHelmet ? "VossIronHelmet" : "VossSplintMail" }
    var atlas: String { character + ".atlas" }
    var paperdollArt: String {
        self == .ironHelmet ? "voss_paperdoll_iron_helmet" : "voss_paperdoll_splint_mail"
    }
    func isEquipped(in inventory: CharacterInventory) -> Bool {
        inventory.equipped[slot]?.id == rawValue
    }

    func frameName(matching body: IEIndexedSprite.FrameID) -> String? {
        guard body.atlas == VossAnimationSet.atlas,
              body.name.hasPrefix("idle_") || body.name.hasPrefix("walk_") else { return nil }
        return body.name
    }

    func validate(_ sprite: IEIndexedSprite) throws {
        guard sprite.character == character,
              sprite.sourceCanvasSize == .init(width: 128, height: 128),
              sprite.compatibilityDisplaySize == .init(x: 140.625, y: 140.625),
              sprite.frames.count == 1200 else {
            throw IEIndexedSpriteError.malformedManifest(reason: "Incomplete or misregistered Voss armor overlay")
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
