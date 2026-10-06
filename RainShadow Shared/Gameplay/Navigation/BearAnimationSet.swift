import Foundation

/// Meshy Grizzly Guardian, authored in Bear_Guardian_Animated.blend through live Blender MCP.
/// Indexed frames retain one camera scale and ground pivot across every pose.
enum BearAnimationSet {
    static let character = "BearGuardian"
    static let atlas = "BearGuardian.atlas"
    static let expectedBlobSHA256 = "4c8465242c9b57fa6faa10a2de2f971bb1a261b96839404c29ded8769ba62c0b"
    static let frameCount = 832
    static func frameCount(for action: CharacterVisualAction) throws -> Int {
        switch action {
        case .idle, .walk, .attack: 12
        case .hit: 6
        case .revert: 10
        default: throw CharacterAppearanceError.unsupportedAction(.bearGuardian, action)
        }
    }
    static func validate(_ sprite: IEIndexedSprite) throws {
        guard sprite.character == character, sprite.blobSHA256 == expectedBlobSHA256,
              sprite.paletteLayout == .bgeeMixed, sprite.frames.count == frameCount else {
            throw IEIndexedSpriteError.malformedManifest(reason: "Expected the approved 832-frame BearGuardian payload")
        }
        for action in [CharacterVisualAction.idle, .walk, .attack, .hit, .revert] {
            for direction in VossAnimationSet.directions {
                for phase in 0..<(try frameCount(for: action)) {
                    let name = String(format: "%@_%@_%02d.png", action.rawValue, direction, phase)
                    guard let frame = sprite.frame(atlas: atlas, name: name), !frame.isEmpty else {
                        throw IEIndexedSpriteError.invalidFrame(atlas: atlas, name: name, reason: "Required bear pose is missing")
                    }
                }
            }
        }
    }
}
