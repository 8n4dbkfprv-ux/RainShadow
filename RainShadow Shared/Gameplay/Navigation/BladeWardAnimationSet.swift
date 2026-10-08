import Foundation

/// Planted casting gesture: draw the free palm inward, trace outward and recover.
enum BladeWardAnimationSet {
    static let body = "HumanBladeWard"
    static let frames = 16
    static let fps = 16.0
    static let duration = Double(frames) / fps
    static let impactTime = 8.0 / fps
    static let hashes: [String: String] = [
        "HumanBladeWard": "1873661574889a433870168892d88d2c6302040328980f77aef59d225998842c",
        "HumanBladeWardSword": "d9de2ddcd9a49fcd226f658191b86b2117692ffc3b8fe98135b775478aa588e1",
        "HumanBladeWardMail": "35a425d65bb7e6fa97e0f9cc681bbffb7d5de49bc3b92b01090f16af296be671",
        "HumanBladeWardHelmet": "28aa1ccb5965196b47eb051e6d6412e27cdbc6ec550a53b283a13b76ff29a147",
    ]
    static func phase(elapsed: Double) -> Int { min(frames - 1, max(0, Int(elapsed * fps))) }
    static func equipment(_ item: CharacterEquipmentCode) -> String {
        CombatReactionAnimationSet.equipment(item).replacingOccurrences(of: CombatReactionAnimationSet.body, with: body)
    }
    static func name(facing: ActorFacing, phase: Int) throws -> String {
        guard (0..<frames).contains(phase) else { throw CharacterAppearanceError.invalidPhase(phase) }
        return String(format: "ward_%@_%02d.png", VossAnimationSet.direction(facing), phase)
    }
    static func validate(_ sprite: IEIndexedSprite, character: String) throws {
        guard sprite.character == character, sprite.blobSHA256 == hashes[character],
              sprite.paletteLayout == .bgeeMixed, sprite.frames.count == frames * 16,
              sprite.sourceCanvasSize == .init(width: 160, height: 160),
              sprite.sourcePivotFromCanvasBottomLeft == .init(x: 80, y: 60),
              sprite.compatibilityDisplaySize == .init(x: 175.78125, y: 175.78125) else {
            throw IEIndexedSpriteError.malformedManifest(reason: "Expected the reviewed Blade Ward animation")
        }
        for facing in ActorFacing.allCases { for phase in 0..<frames {
            let key = try name(facing: facing, phase: phase)
            guard let frame = sprite.frame(atlas: character + ".atlas", name: key), character != body || !frame.isEmpty else {
                throw CharacterAppearanceError.missingFrame(character, key)
            }
        } }
    }
}
