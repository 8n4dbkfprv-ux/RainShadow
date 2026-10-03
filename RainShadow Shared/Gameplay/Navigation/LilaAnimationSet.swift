import Foundation

/// October 2 Desert Sentinel, authored in Blender against local CHFB references.
/// Independent from the historical three-strip Lila resource family.
enum LilaAnimationSet {
    static let character = "LilaSentinel"
    static let atlas = "LilaSentinel.atlas"
    static let idleFrames = 56
    static let walkFrames = 10
    static let frameCount = 1056
    static let directions = ["s", "ssw", "sw", "wsw", "w", "wnw", "nw", "nnw", "n", "nne", "ne", "ene", "e", "ese", "se", "sse"]

    static func direction(_ facing: ActorFacing) -> String {
        directions[facing.rawValue]
    }

    static func validate(_ sprite: IEIndexedSprite) throws {
        guard sprite.character == character, sprite.frames.count == frameCount else {
            throw IEIndexedSpriteError.malformedManifest(reason: "Expected current LilaSentinel with 1056 frames")
        }
        for direction in directions {
            for (clip, count) in [("idle", idleFrames), ("walk", walkFrames)] {
                for phase in 0..<count {
                    let name = String(format: "%@_%@_%02d.png", clip, direction, phase)
                    guard let frame = sprite.frame(atlas: atlas, name: name), !frame.isEmpty else {
                        throw IEIndexedSpriteError.invalidFrame(atlas: atlas, name: name,
                            reason: "Required current Lila pose is missing")
                    }
                }
            }
        }
    }
}
