import Foundation
import CoreGraphics

/// Additive human reactions, registered to the approved Voss body and equipment.
enum CombatReactionAnimationSet {
    static let body = "HumanReactions"
    static let hashes: [String: String] = [
        "HumanReactions": "a7de9ef30934c78b5f172e7e4f1703521bd3916f3187b236ea8b4c8b2f67d31b",
        "HumanReactionsSword": "ef4dee50b707f6edac9efc5786ba5c79e6bdba236d269a4bd0af96b527051eb6",
        "HumanReactionsMail": "e3791e6599ca6520a3eee404096355ea99aa1846ee43635f10b81213623591ba",
        "HumanReactionsHelmet": "331f28c58a9b519dcd3f53858cc0116b973c65cf64dfdb7af2e5180a0d2d465d",
        "HumanReactionsBow": "d8e9796cc15c9b8f98948e40c1f9016879d36ab1deadfaa5720d45ac93fb7cce",
        "HumanReactionsArrow": "f068859ae2c03c26a848ed64ef220d69c467fd2259b815e97b9757ba5a720a08",
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
    static func name(_ kind: CombatReactionKind, facing: ActorFacing, phase: Int) throws -> String {
        guard (0..<kind.frames).contains(phase) else { throw CharacterAppearanceError.invalidPhase(phase) }
        return String(format: "%@_%@_%02d.png", kind.rawValue, VossAnimationSet.direction(facing), phase)
    }
    static func validate(_ sprite: IEIndexedSprite, character: String) throws {
        guard sprite.character == character, sprite.blobSHA256 == hashes[character],
              sprite.paletteLayout == .bgeeMixed, sprite.frames.count == 288,
              sprite.sourceCanvasSize == .init(width: 160, height: 160),
              sprite.sourcePivotFromCanvasBottomLeft == .init(x: 80, y: 60),
              sprite.compatibilityDisplaySize == .init(x: 175.78125, y: 175.78125) else {
            throw IEIndexedSpriteError.malformedManifest(reason: "Expected the approved human reaction payload")
        }
        for kind in CombatReactionKind.allCases { for facing in ActorFacing.allCases { for phase in 0..<kind.frames {
            let key = try name(kind, facing: facing, phase: phase)
            guard let frame = sprite.frame(atlas: character + ".atlas", name: key), character != body || !frame.isEmpty else {
                throw CharacterAppearanceError.missingFrame(character, key)
            }
        } } }
    }
}
