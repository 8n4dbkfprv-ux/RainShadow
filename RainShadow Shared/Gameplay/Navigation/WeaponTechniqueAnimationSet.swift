import Foundation
import CoreGraphics

/// Additive technique payloads. Existing locomotion, melee and bow bundles stay pinned.
enum WeaponTechniqueAnimationSet {
    static let body = "HumanTechniques"
    static let pinning = "HumanPinningShot"
    static let hashes: [String: String] = [
        "HumanTechniques": "0aa7ed79cfc1157cbb1af3859bf6d222c447cf3306665dab4b070f31d31a354e",
        "HumanTechniquesSword": "43780086b9eef812376a292899446977c4f89e89269e7d56b40cf5fec83e5b67",
        "HumanTechniquesMail": "97b1bb344664b57494c4eda4734b45ee76448b989fbdcede0f1260aea26b8fa1",
        "HumanTechniquesHelmet": "08fad5ca7dae6f0e6fed1e906f597322dfa150fad09656f5c67481cff1eb69a9",
        "HumanPinningShot": "313713687a53ebc2968667e2f3aa3bb055570f00d525232ba938d73e4ebb56dd",
    ]
    static func equipment(_ item: CharacterEquipmentCode) -> String? {
        switch item {
        case .lanternShortsword: "HumanTechniquesSword"
        case .splintMail: "HumanTechniquesMail"
        case .ironHelmet: "HumanTechniquesHelmet"
        case .elvenCourtBow, .elvenCourtArrow: nil
        }
    }
    static func name(_ move: CombatManeuver, facing: ActorFacing, phase: Int) throws -> String {
        let count = move == .pinningShot ? 18 : WeaponTechniqueMotion.meleeFrames(move)
        guard move != .aimedShot, (0..<count).contains(phase) else { throw CharacterAppearanceError.invalidPhase(phase) }
        return String(format: "%@_%@_%02d.png", move == .powerStrike ? "power" : move == .feintingCut ? "feint" : "pin",
                      VossAnimationSet.direction(facing), phase)
    }
    static func validate(_ sprite: IEIndexedSprite, character: String) throws {
        let pin = character == pinning
        guard sprite.character == character, sprite.blobSHA256 == hashes[character],
              sprite.paletteLayout == .bgeeMixed, sprite.frames.count == (pin ? 288 : 432),
              sprite.sourceCanvasSize == .init(width: 160, height: 160),
              sprite.sourcePivotFromCanvasBottomLeft == .init(x: 80, y: 60),
              sprite.compatibilityDisplaySize == .init(x: 175.78125, y: 175.78125) else {
            throw IEIndexedSpriteError.malformedManifest(reason: "Expected the approved weapon technique payload")
        }
        for move in pin ? [.pinningShot] : [CombatManeuver.powerStrike, .feintingCut] {
            for facing in ActorFacing.allCases {
                for phase in 0..<(pin ? 18 : WeaponTechniqueMotion.meleeFrames(move)) {
                    let key = try name(move, facing: facing, phase: phase)
                    guard let frame = sprite.frame(atlas: character + ".atlas", name: key),
                          (character != body && !pin) || !frame.isEmpty else {
                        throw CharacterAppearanceError.missingFrame(character, key)
                    }
                }
            }
        }
    }
    static func pinningMuzzle(facing: ActorFacing) -> CGPoint {
        // Rotated with the baked upper body and bow about spine.02 at release.
        let x = 0.1000000015, y = -0.9563003182, z = 1.2426881790
        let angle = Double(facing.rawValue) * .pi / 8
        let density = (1024 / 1.72 * 0.07465790639916813) * (140.625 / 128)
        return CGPoint(x: density * (cos(angle) * x + sin(angle) * y),
            y: density * (sqrt(1 - 0.75 * 0.75) * z - 0.75 * (sin(angle) * x - cos(angle) * y)))
    }
}
