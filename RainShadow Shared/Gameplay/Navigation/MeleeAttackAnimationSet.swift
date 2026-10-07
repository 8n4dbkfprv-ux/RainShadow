import Foundation

/// Additive human melee layers. The approved idle/walk bundles stay unchanged.
enum MeleeAttackAnimationSet {
    static let frames = 12
    static let framesPerSecond = 15.0
    static let impactTime = 6.0 / framesPerSecond
    static let recoveryTime = Double(frames) / framesPerSecond
    static let body = "HumanMelee"
    static let hashes: [String: String] = [
        "HumanMelee": "42d01719486b6af5639270e8c197984375568abad8cf2415d2ec38969ab9646d",
        "HumanMeleeSword": "8b8a0b56c1e046889114756074fc1d6ee46d692008c4535888712f3b82e4f5d9",
        "HumanMeleeMail": "50ca546fd80d455736f68d3986dd2c9142338ead322c6259dfcce9db2e076bf0",
        "HumanMeleeHelmet": "2ce11b105795e3e0ab35ed0edc0d44a9a1d1907811a1014511150deb081b9558",
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
