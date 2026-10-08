import Foundation
import CoreGraphics

/// Additive human reactions, registered to the approved Voss body and equipment.
enum CombatReactionAnimationSet {
    static let body = "HumanReactions"
    static let tripBody = "HumanTripReaction"
    static let knockbackBody = "HumanKnockback"
    static let hashes: [String: String] = [
        "HumanTripReaction": "b33604a26bdb8d5606f9296dc08e444438ac2b0b204044da08433e9a933079d8",
        "HumanTripReactionSword": "d0161282a3653dc699c80ea2de8fae7a2c9991d67afe74d6d9ba5acdb276c0b7",
        "HumanTripReactionMail": "49d52ebd236ca30d248b16a9b67854ffa024f4d4737cb6cfc9a81abe7fd6a740",
        "HumanTripReactionHelmet": "3b8bcff604c37652f7717398503525855e19ec781177f48d67dee46357a2c367",
        "HumanTripReactionBow": "57fac654bea69b5e08364f3fed3840c646af5acbb698d39bebc9ccd1a761636e",
        "HumanReactions": "a7de9ef30934c78b5f172e7e4f1703521bd3916f3187b236ea8b4c8b2f67d31b",
        "HumanReactionsSword": "ef4dee50b707f6edac9efc5786ba5c79e6bdba236d269a4bd0af96b527051eb6",
        "HumanReactionsMail": "e3791e6599ca6520a3eee404096355ea99aa1846ee43635f10b81213623591ba",
        "HumanReactionsHelmet": "331f28c58a9b519dcd3f53858cc0116b973c65cf64dfdb7af2e5180a0d2d465d",
        "HumanReactionsBow": "d8e9796cc15c9b8f98948e40c1f9016879d36ab1deadfaa5720d45ac93fb7cce",
        "HumanReactionsArrow": "f068859ae2c03c26a848ed64ef220d69c467fd2259b815e97b9757ba5a720a08",
        "HumanKnockback": "7c1f598052eab8e70414ad8deabda643357d62212fa4cf1566ec69e86b0e26c8",
        "HumanKnockbackSword": "b9a9983ee39a623b7682a67128afeecd2e2cf3ceb0bbb49504d99227973ed715",
        "HumanKnockbackMail": "fe61285d923cf5d72bcff604e5253faa2068452145d388aab739e411779ba1c8",
        "HumanKnockbackHelmet": "3bd26852c221c826005ac333a5505c319b6df3b5e70f28dacf337cbf5251a49f",
        "HumanKnockbackBow": "aaed1b8cf81d9455cddc9d534a21dd147091715b75f3879ec2c7fcff9a1ea161",
        "HumanKnockbackArrow": "6f3349c8b5b9008a63e21cc4374e441bebe173e9c234f9716cff0d245305446b",
    ]
    static func equipment(_ item: CharacterEquipmentCode) -> String {
        switch item {
        case .lanternShortsword: "HumanReactionsSword"
        case .splintMail: "HumanReactionsMail"
        case .ironHelmet: "HumanReactionsHelmet"
        case .elvenCourtBow: "HumanReactionsBow"
        case .elvenCourtArrow: "HumanReactionsArrow"
        }
    }
    static func kinds(for character: String) -> [CombatReactionKind] {
        character.hasPrefix(tripBody) ? [.tripFall] : character.hasPrefix(knockbackBody) ? [.stumble, .fall] : [.hit, .dodge]
    }
    /// The carried arrow is stowed so the free hand can brace the floor.
    static func tripEquipment(_ item: CharacterEquipmentCode) -> String? {
        item == .elvenCourtArrow ? nil : equipment(item).replacingOccurrences(of: body, with: tripBody)
    }
    static func knockbackEquipment(_ item: CharacterEquipmentCode) -> String {
        equipment(item).replacingOccurrences(of: body, with: knockbackBody)
    }
    static func name(_ kind: CombatReactionKind, facing: ActorFacing, phase: Int) throws -> String {
        guard (0..<kind.frames).contains(phase) else { throw CharacterAppearanceError.invalidPhase(phase) }
        return String(format: "%@_%@_%02d.png", kind.rawValue, VossAnimationSet.direction(facing), phase)
    }
    static func validate(_ sprite: IEIndexedSprite, character: String) throws {
        guard sprite.character == character, sprite.blobSHA256 == hashes[character],
              sprite.paletteLayout == .bgeeMixed, sprite.frames.count == (character.hasPrefix(tripBody) ? 384 : character.hasPrefix(knockbackBody) ? 640 : 288),
              sprite.sourceCanvasSize == .init(width: 160, height: 160),
              sprite.sourcePivotFromCanvasBottomLeft == .init(x: 80, y: 60),
              sprite.compatibilityDisplaySize == .init(x: 175.78125, y: 175.78125) else {
            throw IEIndexedSpriteError.malformedManifest(reason: "Expected the approved human reaction payload")
        }
        for kind in kinds(for: character) { for facing in ActorFacing.allCases { for phase in 0..<kind.frames {
            let key = try name(kind, facing: facing, phase: phase)
            guard let frame = sprite.frame(atlas: character + ".atlas", name: key), (character != body && character != knockbackBody && character != tripBody) || !frame.isEmpty else {
                throw CharacterAppearanceError.missingFrame(character, key)
            }
        } } }
    }
}
