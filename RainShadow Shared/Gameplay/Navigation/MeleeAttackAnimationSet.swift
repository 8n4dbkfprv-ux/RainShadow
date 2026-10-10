import Foundation

/// Additive human melee layers. The approved idle/walk bundles stay unchanged.
enum MeleeAttackAnimationSet {
    static let frames = 12
    static let framesPerSecond = 15.0
    static let impactTime = 6.0 / framesPerSecond
    static let recoveryTime = Double(frames) / framesPerSecond
    static let body = "HumanMelee"
    static let hashes: [String: String] = [
        "HumanMelee": "a582910f48c390eee38810b484fe956273bdd6168e0c8bb81eefc012ed9b7232",
        "HumanMeleeSword": "403ec19ec91bd27683e8d4c8a2da5d3db40cfd0c1959273a525964e66bb10f72",
        "HumanMeleeMail": "7a846cd1c6fc7fde1dd500be4d3aa617dd683c82a77334fbea71b4a3f874ce19",
        "HumanMeleeHelmet": "097aee9aad0d574c828ff616db5069d99dee83cb7bdc446384fc01f9a8fed779",
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
