import Foundation
import CoreGraphics

/// Additive poses; VossCHMF remains the authority for normal locomotion.
enum StealthClip: String, CaseIterable {
    case hide, sneakidle, sneakwalk, sneakstab, sneakshoot
    var frames: Int {
        switch self { case .hide: 8; case .sneakidle: 6; case .sneakwalk: 12; case .sneakstab: 18; case .sneakshoot: 24 }
    }
    var action: CharacterVisualAction {
        switch self { case .sneakwalk: .walk; case .sneakstab: .attack; case .sneakshoot: .shoot; default: .idle }
    }
}
enum StealthAnimationSet {
    static let body = "HumanStealth"
    static let bow = "HumanSneakShot"
    static let fps = 15.0
    static let stabImpact = 9.0 / fps
    static let stabDuration = 18.0 / fps
    // Continuous jump: anticipation, takeoff, airborne release, then landing.
    static let bowReleasePhase = 12
    static let bowRelease = Double(bowReleasePhase) / fps
    static let bowDuration = Double(StealthClip.sneakshoot.frames) / fps
    // Live-Blender renders: October 7 stealth poses and October 9 jumping bow shot.
    static let hashes: [String: String] = [
        "HumanStealth": "bcceff48a55f03e2b37e7a04ec7725fdba2117561af0d88b8a72927fa48991e8",
        "HumanStealthSword": "d544412b3179c7e4419aba3cb6451ec3b7b661acacc4d19798400fb3b7f7cd59",
        "HumanStealthMail": "e4b40c9a2cff1fa17d4f582ca68afb6ea32bad1d57d390fcf307a75c796b4b58",
        "HumanStealthHelmet": "6ec640bceb07e5e06e9c51794f4483ebdd7ef57271bdf26f3e99725bc6a92e15",
        "HumanStealthBow": "05c89e307fbd04fae6ccf66d991a8071b206209c136db1ebda69eba7ad5f3765",
        "HumanStealthArrow": "0dd456432c154454f4bcab06a419f7bc920eb309947a08dbd1a187444ec998e9",
        "HumanSneakShot": "49b583a67d2fea34c9d2b354d975170b53f56a9a2619f999b774d775c07b0674",
    ]
    static func equipment(_ item: CharacterEquipmentCode) -> String {
        CombatReactionAnimationSet.equipment(item).replacingOccurrences(of: CombatReactionAnimationSet.body, with: body)
    }
    static func name(_ clip: StealthClip, facing: ActorFacing, phase: Int) throws -> String {
        guard (0..<clip.frames).contains(phase) else { throw CharacterAppearanceError.invalidPhase(phase) }
        return String(format: "%@_%@_%02d.png", clip.rawValue, VossAnimationSet.direction(facing), phase)
    }
    static func phase(_ clip: StealthClip, elapsed: Double, looping: Bool = false) -> Int {
        let frame = max(0, Int(elapsed * fps + 1e-9))
        return looping ? frame % clip.frames : min(clip.frames - 1, frame)
    }
    static func usesAttack(_ strike: TacticalCombat.Strike) -> Bool {
        // Explicit failed attempts still use their authored attack animation.
        strike.maneuver == nil && (strike.requestedSneakAttack || strike.sneakDamage > 0)
    }
    static func muzzleOffset(facing: ActorFacing) -> CGPoint {
        let angle = Double(facing.rawValue) * .pi / 8
        let density = (1024 / 1.72 * 0.07465790639916813) * (140.625 / 128)
        // Last nocked tip, carried down 4 cm with the root at release (phase 12).
        // Excludes the source arrow's forward motion; the projectile owns flight.
        let x = 0.10000031, y = -0.95111811, z = 2.03376790
        return CGPoint(x: density * (cos(angle) * x + sin(angle) * y),
            y: density * (sqrt(1 - 0.75 * 0.75) * z - 0.75 * (sin(angle) * x - cos(angle) * y)))
    }
    static func validate(_ sprite: IEIndexedSprite, character: String) throws {
        let clips: [StealthClip] = character == bow ? [.sneakshoot] : [.hide, .sneakidle, .sneakwalk, .sneakstab]
        guard sprite.character == character, sprite.blobSHA256 == hashes[character],
              sprite.paletteLayout == .bgeeMixed, sprite.frames.count == clips.reduce(0, { $0 + $1.frames }) * 16,
              sprite.sourceCanvasSize == .init(width: 160, height: 160),
              sprite.sourcePivotFromCanvasBottomLeft == .init(x: 80, y: 60),
              sprite.compatibilityDisplaySize == .init(x: 175.78125, y: 175.78125) else {
            throw IEIndexedSpriteError.malformedManifest(reason: "Expected the reviewed stealth payload")
        }
        for clip in clips { for facing in ActorFacing.allCases { for phase in 0..<clip.frames {
            let key = try name(clip, facing: facing, phase: phase)
            guard let frame = sprite.frame(atlas: character + ".atlas", name: key),
                  (character != body && character != bow) || !frame.isEmpty else {
                throw CharacterAppearanceError.missingFrame(character, key)
            }
        } } }
    }
}
