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
        case .idle, .walk: 12
        case .attack: BearClawAnimationSet.frames
        case .hit: 6
        case .revert: 10
        case .roar: BearRoarAnimationSet.frames
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
                // The original package retains its legacy 12-frame swipe.
                for phase in 0..<(action == .attack ? 12 : try frameCount(for: action)) {
                    let name = String(format: "%@_%@_%02d.png", action.rawValue, direction, phase)
                    guard let frame = sprite.frame(atlas: atlas, name: name), !frame.isEmpty else {
                        throw IEIndexedSpriteError.invalidFrame(atlas: atlas, name: name, reason: "Required bear pose is missing")
                    }
                }
            }
        }
    }
}

/// Additive roar: the approved locomotion, swipe and transformation payload stays intact.
enum BearRoarAnimationSet {
    static let character = "BearGuardianRoar"
    static let frames = 24
    static let expectedBlobSHA256 = "da3fd1ccd64bc77a414519704dc617eee0ad689fe5645c446ff9e9cb85db48b6"
    static func validate(_ sprite: IEIndexedSprite) throws {
        guard sprite.character == character, sprite.blobSHA256 == expectedBlobSHA256,
              sprite.paletteLayout == .bgeeMixed, sprite.frames.count == frames * 16,
              sprite.sourceCanvasSize == .init(width: 128, height: 128),
              sprite.compatibilityDisplaySize == .init(x: 180, y: 180) else {
            throw IEIndexedSpriteError.malformedManifest(reason: "Expected the approved BearGuardianRoar payload")
        }
        for facing in ActorFacing.allCases { for phase in 0..<frames {
            let name = try CharacterBodyCode.bearGuardian.frameName(action: .roar, facing: facing, phase: phase)
            guard let frame = sprite.frame(atlas: character + ".atlas", name: name), !frame.isEmpty else {
                throw CharacterAppearanceError.missingFrame(character, name)
            }
        } }
    }
}

/// Rear-up, diagonal strike and weighted landing, with the original registration.
enum BearClawAnimationSet {
    static let character = "BearGuardianClaw"
    static let frames = 24
    static let expectedBlobSHA256 = "29c31ef6b19545d2f000290f2c06268e6e044dd46c186ca2deeb48e20e8e50e1"
    static func validate(_ sprite: IEIndexedSprite) throws {
        guard sprite.character == character, sprite.blobSHA256 == expectedBlobSHA256,
              sprite.paletteLayout == .bgeeMixed, sprite.frames.count == frames * 16,
              sprite.sourceCanvasSize == .init(width: 128, height: 128),
              sprite.compatibilityDisplaySize == .init(x: 180, y: 180) else {
            throw IEIndexedSpriteError.malformedManifest(reason: "Expected the approved BearGuardianClaw payload")
        }
        for facing in ActorFacing.allCases { for phase in 0..<frames {
            let name = try CharacterBodyCode.bearGuardian.frameName(action: .attack, facing: facing, phase: phase)
            guard let frame = sprite.frame(atlas: character + ".atlas", name: name), !frame.isEmpty else {
                throw CharacterAppearanceError.missingFrame(character, name)
            }
        } }
    }
}
