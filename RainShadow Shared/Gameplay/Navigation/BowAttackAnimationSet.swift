import Foundation
import CoreGraphics

/// Additive shot clip; never replaces VossCHMF's approved idle/walk payload.
enum BowAttackAnimationSet {
    static let character = "WharfLookoutShot"
    static let atlas = character + ".atlas"
    static let expectedBlobSHA256 = "254550ed657112f5a126ccbe6aa73fa2834772755a77153b040af19332e6f6fd"
    static func validate(_ sprite: IEIndexedSprite) throws {
        guard sprite.character == character, sprite.blobSHA256 == expectedBlobSHA256,
              sprite.paletteLayout == .bgeeMixed, sprite.frames.count == BowAttackRules.frames * 16 else {
            throw IEIndexedSpriteError.malformedManifest(reason: "Expected the approved lookout shot payload")
        }
        for direction in VossAnimationSet.directions { for phase in 0..<BowAttackRules.frames {
            let name = String(format: "shoot_%@_%02d.png", direction, phase)
            guard let frame = sprite.frame(atlas: atlas, name: name), !frame.isEmpty else {
                throw IEIndexedSpriteError.invalidFrame(atlas: atlas, name: name, reason: "Missing lookout firing pose")
            }
        }}
    }
    /// All three bow clips share equipment bundles, with independently rendered
    /// holdouts for the bow, string, arrow and body at each authored pose.
    static let armorHashes: [String: String] = [
        "HumanBowMail": "93bd4dfba9291a969ecf0bebf512357d7163d8f236ca66d5f76202d5236a3684",
        "HumanBowHelmet": "06f5a90553701b8e1fc94c62817767d62e4e230b73281c29a525d991ef701a9c",
    ]
    static func equipment(_ item: CharacterEquipmentCode) -> String? {
        switch item {
        case .splintMail: "HumanBowMail"
        case .ironHelmet: "HumanBowHelmet"
        default: nil
        }
    }
    static func validateEquipment(_ sprite: IEIndexedSprite, character: String) throws {
        guard sprite.character == character, sprite.blobSHA256 == armorHashes[character],
              sprite.paletteLayout == .bgeeMixed, sprite.frames.count == 3 * BowAttackRules.frames * 16,
              sprite.sourceCanvasSize == .init(width: 160, height: 160),
              sprite.sourcePivotFromCanvasBottomLeft == .init(x: 80, y: 60),
              sprite.compatibilityDisplaySize == .init(x: 175.78125, y: 175.78125) else {
            throw IEIndexedSpriteError.malformedManifest(reason: "Expected the reviewed armored bow equipment")
        }
        for clip in ["shoot", "pin", "sneakshoot"] {
            for direction in VossAnimationSet.directions { for phase in 0..<BowAttackRules.frames {
                let name = String(format: "%@_%@_%02d.png", clip, direction, phase)
                guard let frame = sprite.frame(atlas: character + ".atlas", name: name), !frame.isEmpty else {
                    throw CharacterAppearanceError.missingFrame(character, name)
                }
            } }
        }
    }
    /// Authored arrow tip immediately before release, projected with the same
    /// camera/density as the clip. The runtime flight starts here, not at feet.
    static func muzzleOffset(facing: ActorFacing) -> CGPoint {
        let angle = Double(facing.rawValue) * .pi / 8
        let density = (1024 / 1.72 * 0.07465790639916813) * (140.625 / 128)
        let x = 0.10, y = -0.926118, z = 1.453768
        return CGPoint(x: density * (cos(angle) * x + sin(angle) * y),
            y: density * (sqrt(1 - 0.75 * 0.75) * z - 0.75 * (sin(angle) * x - cos(angle) * y)))
    }
}
