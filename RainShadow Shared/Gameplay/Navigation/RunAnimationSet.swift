import Foundation

/// Additive Dash locomotion; approved ordinary walking bundles remain unchanged.
enum RunAnimationSet {
    static let body = "HumanRun"
    static let bear = "BearGuardianRun"
    static let frames = 16
    static let hashes: [String: String] = [
        "BearGuardianRun": "e59c88f69e5a034c633dccef641f6d131355f578ac8d7a60a7e512075cefa6d2",
        "HumanRun": "6b53a1bf5242695ee7156071046d767948c1a39e09976ba3869c641974be29ef",
        "HumanRunSword": "e440491764215204e5efda0413056ecedde24f40f4de951e41473051789ee9c6",
        "HumanRunMail": "d121f1aaaf3f84b90423eb469b9454fcc7b88cfdcc4bafe391d780b20dd38b1b",
        "HumanRunHelmet": "06b9dc2ff0868b157d1e7d0b41d2cdbb4e69d82766ebc4da2719108a4bf839b1",
        "HumanRunBow": "2985835829bd978fcfc30501c0c940525984c7f3f666b6532edc565b6517e49d",
    ]
    static func equipment(_ item: CharacterEquipmentCode) -> String {
        CombatReactionAnimationSet.equipment(item).replacingOccurrences(of: CombatReactionAnimationSet.body, with: body)
    }
    static func name(facing: ActorFacing, phase: Int) throws -> String {
        guard (0..<frames).contains(phase) else { throw CharacterAppearanceError.invalidPhase(phase) }
        return String(format: "run_%@_%02d.png", VossAnimationSet.direction(facing), phase)
    }
    static func validate(_ sprite: IEIndexedSprite, character: String) throws {
        let isBear = character == bear
        guard sprite.character == character, sprite.blobSHA256 == hashes[character],
              sprite.paletteLayout == .bgeeMixed, sprite.frames.count == frames * 16,
              sprite.sourceCanvasSize == .init(width: isBear ? 128 : 160, height: isBear ? 128 : 160),
              sprite.sourcePivotFromCanvasBottomLeft == .init(x: isBear ? 64 : 80, y: isBear ? 53.416996002197266 : 60),
              sprite.compatibilityDisplaySize == .init(x: isBear ? 180 : 175.78125, y: isBear ? 180 : 175.78125) else {
            throw IEIndexedSpriteError.malformedManifest(reason: "Expected the reviewed Dash running animation")
        }
        for facing in ActorFacing.allCases { for phase in 0..<frames {
            let key = try name(facing: facing, phase: phase)
            guard let frame = sprite.frame(atlas: character + ".atlas", name: key),
                  (character != body && !isBear) || !frame.isEmpty else {
                throw CharacterAppearanceError.missingFrame(character, key)
            }
        } }
    }
}

/// Presentation pacing only: distance costs and the engine's integral steps stay unchanged.
enum CombatRunMotion {
    static let recoveryDuration = 0.12
    // Authored support-phase paw/foot sweep divided by its share of the cycle,
    // then converted through the fixed render camera and display scale.
    static func stride(bear: Bool) -> Double { bear ? (0.65 / 0.46) * 180 / 3.6 : (0.60 / 0.45) * (1024 / 1.72 * 0.07465790639916813) * 175.78125 / 160 }
    static func phase(distance: Double, bear: Bool) -> Int {
        Int(max(0, distance) / stride(bear: bear) * Double(RunAnimationSet.frames)) % RunAnimationSet.frames
    }
    static func rate(travelled: Double, remaining: Double) -> Double {
        let t = min(1, max(0, min(travelled / 30, remaining / 32)))
        return 0.55 + 1.1 * t * t * (3 - 2 * t)
    }
}
