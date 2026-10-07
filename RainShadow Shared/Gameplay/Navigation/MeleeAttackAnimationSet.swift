import Foundation

/// Additive human melee layers. The approved idle/walk bundles stay unchanged.
enum MeleeAttackAnimationSet {
    static let frames = 12
    static let framesPerSecond = 15.0
    static let impactTime = 6.0 / framesPerSecond
    static let recoveryTime = Double(frames) / framesPerSecond
    static let body = "HumanMelee"
    static let hashes: [String: String] = [
        "HumanMelee": "8fe80af08a2ce262e02fabeb04f4f0ce18d6c976b391d6aa8da57fe48165a3ea",
        "HumanMeleeSword": "e06ae70293a7c174d344168329f848a6d062da06f56ab3f5e6ccd2a49a2f3678",
        "HumanMeleeMail": "7c19e91c1ce6229f775089f3dd66d62ff482cfc4e585d331122780d9bcb21e4e",
        "HumanMeleeHelmet": "ed27aac932983e212f144b98a6d20509da961fe93a60976f6214a3f19c3e1391",
    ]

    static func equipment(_ item: CharacterEquipmentCode) -> String? {
        switch item {
        case .lanternShortsword: "HumanMeleeSword"
        case .splintMail: "HumanMeleeMail"
        case .ironHelmet: "HumanMeleeHelmet"
        case .elvenCourtBow, .elvenCourtArrow: nil
        }
    }

    static func validate(_ sprite: IEIndexedSprite, character: String) throws {
        guard sprite.character == character, sprite.blobSHA256 == hashes[character],
              sprite.paletteLayout == .bgeeMixed, sprite.frames.count == frames * 16,
              sprite.sourceCanvasSize == .init(width: 160, height: 160),
              sprite.compatibilityDisplaySize == .init(x: 175.78125, y: 175.78125) else {
            throw IEIndexedSpriteError.malformedManifest(reason: "Expected the approved human melee layer")
        }
        for direction in VossAnimationSet.directions { for phase in 0..<frames {
            let name = String(format: "attack_%@_%02d.png", direction, phase)
            guard let frame = sprite.frame(atlas: character + ".atlas", name: name),
                  character != body || !frame.isEmpty else {
                throw IEIndexedSpriteError.invalidFrame(atlas: character + ".atlas", name: name,
                    reason: "Missing synchronized melee pose")
            }
        }}
    }
}
