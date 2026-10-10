import Foundation

/// Open-palm push with a planted stance and a held weapon; contact is phase five.
enum ShoveAnimationSet {
    static let body = "HumanShove"
    static let frames = 12
    // Source phases 0–3 prepare the palm, 3–6 deliver the push, and 6–11
    // recover. Extend only preparation/recovery; keep the forward push crisp.
    static let fps = 18.0
    static let windupTime = 0.4
    static let duration = 1.1
    static let impactTime = windupTime + 2.0 / fps
    private static let recoveryStart = windupTime + 3.0 / fps
    static let hashes: [String: String] = [
        "HumanShove": "db5924131beab1e3f031bc693c64e9db5f53d21612f65664f64a265e7c63058b",
        "HumanShoveSword": "6ce52160fad7536c90894f2af58afbca13910da040e0dc748eeac5ffb131bdb6",
        "HumanShoveMail": "976c1d1a7dc5a7974a4990e07582f221de6245c8ac1877494d310b579d627e82",
        "HumanShoveHelmet": "07cdb2deea47eaa13b4cd9e2470b4d1a49da7808d56cbc07e1b5876967728850",
        "HumanShoveBow": "310e0632ec7efa3d03cb6def08e62880319afc03fec1996dafece934dd9c6046",
    ]
    static func phase(elapsed: Double) -> Int {
        let time = min(duration, max(0, elapsed))
        let frame: Double
        if time < windupTime {
            frame = time / windupTime * 3
        } else if time < recoveryStart {
            frame = 3 + (time - windupTime) * fps
        } else {
            frame = 6 + (time - recoveryStart) / (duration - recoveryStart) * 6
        }
        return min(frames - 1, max(0, Int(frame + 1e-9)))
    }
    static func equipment(_ item: CharacterEquipmentCode) -> String {
        CombatReactionAnimationSet.equipment(item).replacingOccurrences(of: CombatReactionAnimationSet.body, with: body)
    }
    static func name(facing: ActorFacing, phase: Int) throws -> String {
        guard (0..<frames).contains(phase) else { throw CharacterAppearanceError.invalidPhase(phase) }
        return String(format: "shove_%@_%02d.png", VossAnimationSet.direction(facing), phase)
    }
    static func validate(_ sprite: IEIndexedSprite, character: String) throws {
        guard sprite.character == character, sprite.blobSHA256 == hashes[character],
              sprite.paletteLayout == .bgeeMixed, sprite.frames.count == frames * 16,
              sprite.sourceCanvasSize == .init(width: 160, height: 160),
              sprite.sourcePivotFromCanvasBottomLeft == .init(x: 80, y: 60),
              sprite.compatibilityDisplaySize == .init(x: 175.78125, y: 175.78125) else {
            throw IEIndexedSpriteError.malformedManifest(reason: "Expected the reviewed shove animation")
        }
        for facing in ActorFacing.allCases { for phase in 0..<frames {
            let key = try name(facing: facing, phase: phase)
            guard let frame = sprite.frame(atlas: character + ".atlas", name: key), character != body || !frame.isEmpty else {
                throw CharacterAppearanceError.missingFrame(character, key)
            }
        } }
    }
}
