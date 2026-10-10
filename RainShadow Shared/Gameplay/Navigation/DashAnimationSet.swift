import Foundation

/// Stationary Dash preparation and release; movement remains a separate order.
enum DashAnimationSet {
    static let body = "HumanDash"
    static let frames = 12
    static let duration = 0.9
    static let impactTime = 0.375
    static let fps = Double(frames) / duration
    static let hashes: [String: String] = [
        "HumanDash": "44aac225883e7b23c4f3f9042861c4d109d3c4a166dfbc0bf1211e66b0abb065",
        "HumanDashSword": "e87614346de20604336e24787d62b6fd4637b5dcce86b80fa4aab1b9b39f3ea8",
        "HumanDashMail": "ca05aa91f1b39881a7bc07c9c350d88c9b08ebe36f107a0a6668f76622aac1b9",
        "HumanDashHelmet": "56ac0abbb6c9e8c61e53b7a1faf77e81ceee2bb83399f00abaa59636aaf73c06",
        "HumanDashBow": "349659eba60f3e743a07e9f71271f6a6e96ff88e531029f7d22da89c36ad7986",
    ]
    static func phase(elapsed: Double) -> Int {
        min(frames - 1, max(0, Int(max(0, elapsed) * fps + 1e-9)))
    }
    static func equipment(_ item: CharacterEquipmentCode) -> String {
        CombatReactionAnimationSet.equipment(item).replacingOccurrences(of: CombatReactionAnimationSet.body, with: body)
    }
    static func name(facing: ActorFacing, phase: Int) throws -> String {
        guard (0..<frames).contains(phase) else { throw CharacterAppearanceError.invalidPhase(phase) }
        return String(format: "dash_%@_%02d.png", VossAnimationSet.direction(facing), phase)
    }
    static func validate(_ sprite: IEIndexedSprite, character: String) throws {
        guard sprite.character == character, sprite.blobSHA256 == hashes[character],
              sprite.paletteLayout == .bgeeMixed, sprite.frames.count == frames * 16,
              sprite.sourceCanvasSize == .init(width: 160, height: 160),
              sprite.sourcePivotFromCanvasBottomLeft == .init(x: 80, y: 60),
              sprite.compatibilityDisplaySize == .init(x: 175.78125, y: 175.78125) else {
            throw IEIndexedSpriteError.malformedManifest(reason: "Expected the reviewed Dash animation")
        }
        for facing in ActorFacing.allCases { for phase in 0..<frames {
            let key = try name(facing: facing, phase: phase)
            guard let frame = sprite.frame(atlas: character + ".atlas", name: key), character != body || !frame.isEmpty else {
                throw CharacterAppearanceError.missingFrame(character, key)
            }
        } }
    }
}
