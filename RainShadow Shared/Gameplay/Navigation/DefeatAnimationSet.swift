import Foundation

/// One-shot collapse. The terminal pose is held, never wrapped back to standing.
enum DefeatAnimationSet {
    static let body = "HumanDefeat"
    static let frames = 18
    static let fps = 15.0
    static let duration = Double(frames) / fps
    static let hashes: [String: String] = [
        "HumanDefeat": "490b6711076c0980a28155a03e8b8b13d2aff26556a9b3567ae5e67298d9c789",
        "HumanDefeatSword": "f1b084ad1350d982f7cc36da3e53e1052d69a5d9e8b4d8ea9c6e2763830507f7",
        "HumanDefeatMail": "1afbfec40ca6ff5a781d4b7e8398918df5dd9a96fa230da1b8e6148d8b6bac14",
        "HumanDefeatHelmet": "d6a6868287eb1db7c656f86d2f27fe8a5500a15a49fe6f35b3c85ff9307005ac",
        "HumanDefeatBow": "30e337f21609a4225af286c9f04a27fb3f06a3569a99859c7f443225e41fb069",
        "HumanDefeatArrow": "43f33c03e9e59b6ec119c33f8e2bd2d6d52aeec8c7c3f14fd607e9f0f4f7fa84",
    ]
    static func phase(elapsed: Double) -> Int { min(frames - 1, max(0, Int(elapsed * fps))) }
    static func equipment(_ item: CharacterEquipmentCode) -> String {
        CombatReactionAnimationSet.equipment(item).replacingOccurrences(of: CombatReactionAnimationSet.body, with: body)
    }
    static func name(facing: ActorFacing, phase: Int) throws -> String {
        guard (0..<frames).contains(phase) else { throw CharacterAppearanceError.invalidPhase(phase) }
        return String(format: "die_%@_%02d.png", VossAnimationSet.direction(facing), phase)
    }
    static func validate(_ sprite: IEIndexedSprite, character: String) throws {
        guard sprite.character == character, sprite.blobSHA256 == hashes[character],
              sprite.paletteLayout == .bgeeMixed, sprite.frames.count == frames * 16,
              sprite.sourceCanvasSize == .init(width: 160, height: 160),
              sprite.sourcePivotFromCanvasBottomLeft == .init(x: 80, y: 60),
              sprite.compatibilityDisplaySize == .init(x: 175.78125, y: 175.78125) else {
            throw IEIndexedSpriteError.malformedManifest(reason: "Expected the reviewed defeat animation")
        }
        for facing in ActorFacing.allCases { for phase in 0..<frames {
            let key = try name(facing: facing, phase: phase)
            guard let frame = sprite.frame(atlas: character + ".atlas", name: key), character != body || !frame.isEmpty else {
                throw CharacterAppearanceError.missingFrame(character, key)
            }
        } }
    }
}
struct CombatDefeatMotion {
    let facing: ActorFacing
    var elapsed: Double = 0
    var phase: Int { DefeatAnimationSet.phase(elapsed: elapsed) }
    var finished: Bool { elapsed >= DefeatAnimationSet.duration }
}
