import Foundation

/// Additive Dash locomotion; approved ordinary walking bundles remain unchanged.
enum RunAnimationSet {
    static let body = "HumanRun"
    static let bear = "BearGuardianRun"
    static let frames = 16
    static let hashes: [String: String] = [
        "BearGuardianRun": "e59c88f69e5a034c633dccef641f6d131355f578ac8d7a60a7e512075cefa6d2",
        "HumanRun": "1f3d42dd17db2cc3bf277cee113de02207a05e9f71e7c9c979ad8348747cf189",
        "HumanRunSword": "ee0c2ff5ab9ad51ddf4b1a6499562b2e87809c6a0e24e5134e798397905a72d7",
        "HumanRunMail": "df862c7f8324c5fa57d44550b821c74b634a294038cab68a72d7b62337c6a22e",
        "HumanRunHelmet": "7e4cfcf0424084e0a4d2360d717f443556fa80e607e521d308503a63a1609b65",
        "HumanRunBow": "2663f32aa44b803a1ca4775e7944a6415b6f197cda7e922fa44fe91e57729bfe",
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
    static func stride(bear: Bool) -> Double { bear ? (0.65 / 0.46) * 180 / 3.6 : (0.70 / 0.45) * (1024 / 1.72 * 0.07465790639916813) * 175.78125 / 160 }
    static func phase(distance: Double, bear: Bool) -> Int {
        Int(max(0, distance) / stride(bear: bear) * Double(RunAnimationSet.frames)) % RunAnimationSet.frames
    }
    static func rate(travelled: Double, remaining: Double) -> Double {
        let t = min(1, max(0, min(travelled / 30, remaining / 32)))
        return 0.55 + 1.1 * t * t * (3 - 2 * t)
    }
}
