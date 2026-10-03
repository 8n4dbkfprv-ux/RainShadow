import Foundation

/// Current character identity, independent of historical atlases and master selectors.
/// The reviewed September 22 family includes September 23's explicit SW chair.
enum VossAnimationSet {
    static let character = "VossCHMF"
    static let atlas = "VossCHMF.atlas"
    static let frameCount = 1556
    static let idleFrames = 65
    static let walkFrames = 10
    static let transitionFrames = 12
    static let idleSecondsPerFrame = 1.0 / 15.0
    static let directions = ["s", "ssw", "sw", "wsw", "w", "wnw", "nw", "nnw", "n", "nne", "ne", "ene", "e", "ese", "se", "sse"]

    static func direction(_ facing: ActorFacing) -> String {
        directions[facing.rawValue]
    }

    /// Missing or stale character art is an installation error, never permission
    /// to substitute the old detective. All poses are validated before display.
    static func validate(_ sprite: IEIndexedSprite) throws {
        guard sprite.character == character,
              sprite.paletteLayout == .bgeeMixed,
              sprite.frames.count == frameCount else {
            throw IEIndexedSpriteError.malformedManifest(reason: "Expected current VossCHMF with 1556 frames")
        }
        for direction in directions {
            try require(sprite, clip: "idle", direction: direction, count: idleFrames)
            try require(sprite, clip: "walk", direction: direction, count: walkFrames)
        }
        for direction in ["nw", "se", "n", "sw"] {
            try require(sprite, clip: "seated_idle", direction: direction, count: idleFrames)
            try require(sprite, clip: "stand_up", direction: direction, count: transitionFrames)
            try require(sprite, clip: "sit_down", direction: direction, count: transitionFrames)
        }
    }

    private static func require(_ sprite: IEIndexedSprite, clip: String, direction: String, count: Int) throws {
        for phase in 0..<count {
            let name = String(format: "%@_%@_%02d.png", clip, direction, phase)
            guard let frame = sprite.frame(atlas: atlas, name: name), !frame.isEmpty else {
                throw IEIndexedSpriteError.invalidFrame(atlas: atlas, name: name, reason: "Required current Voss pose is missing")
            }
        }
    }
}
