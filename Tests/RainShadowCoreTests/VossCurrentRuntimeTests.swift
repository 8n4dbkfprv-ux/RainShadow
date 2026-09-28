import CryptoKit
import Foundation
import Testing
@testable import RainShadowCore

struct VossCurrentRuntimeTests {
    private struct Animation: Decodable {
        struct Frame: Decodable {
            struct Indexed: Decodable { let character: String; let atlas: String; let name: String }
            let indexed: Indexed?
        }
        struct Sequence: Decodable { let id: String; let frames: [String] }
        let frames: [Frame]
        let sequences: [Sequence]
    }

    @Test func currentBundleIsTheReviewedCharacterAndEverySequenceIsComplete() throws {
        let sprite = try IEIndexedSprite.load(character: VossAnimationSet.character)
        try VossAnimationSet.validate(sprite)
        let directory = IEGradientTables.developmentDirectory.appendingPathComponent("Avatars/VossCHMF")
        let bytes = try Data(contentsOf: directory.appendingPathComponent("avatar-v02.indices"))
        #expect(SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
                == "e1b1e7c70453e619b8a5a9ffdbaaec0d70077d5aa83857ecb024f93cc19b36ab")
        #expect(sprite.sourceCanvasSize == .init(width: 128, height: 128))
        #expect(sprite.compatibilityDisplaySize == .init(x: 140.625, y: 140.625))
        #expect(sprite.hasEmbeddedShadow)
        let animation = try JSONDecoder().decode(Animation.self, from: Data(contentsOf: directory.appendingPathComponent("source.animation.json")))
        #expect(animation.frames.count == 1556 && animation.sequences.count == 44)
        for frame in animation.frames {
            let indexed = try #require(frame.indexed)
            #expect(indexed.character == VossAnimationSet.character)
            #expect(sprite.frame(atlas: indexed.atlas, name: indexed.name) != nil)
        }
    }

    @Test func allNativePixelsResolveToTheReviewedPalette() throws {
        let sprite = try IEIndexedSprite.load(character: VossAnimationSet.character)
        var hash = SHA256()
        for frame in sprite.frames { hash.update(data: Data(sprite.rgba(for: frame))) }
        // Independently resolved from the reviewed planes and pal16.bin using
        // the source pair ordering, integer sample columns and channel means.
        #expect(hash.finalize().map { String(format: "%02x", $0) }.joined()
                == "3bb2f60a7afc7524ec49f2b5cb12c8693d88012079b8056d1af93ab830c7da95")
    }

    @Test func oldDetectiveCannotSatisfyTheCurrentCharacterContract() throws {
        let old = try IEIndexedSprite.load(character: "Voss")
        #expect(throws: IEIndexedSpriteError.self) { try VossAnimationSet.validate(old) }
        #expect(old.paletteLayout == .gemrbAliases)
    }

    @Test func chairEndpointsRetainRegistration() throws {
        let sprite = try IEIndexedSprite.load(character: VossAnimationSet.character)
        func plane(_ name: String) throws -> [UInt8] {
            let frame = try #require(sprite.frame(atlas: VossAnimationSet.atlas, name: name + ".png"))
            var result = [UInt8](repeating: 0, count: 128 * 128)
            for y in 0..<frame.nativeSize.height {
                for x in 0..<frame.nativeSize.width {
                    result[(y + frame.trimOriginTopLeft.height) * 128 + x + frame.trimOriginTopLeft.width] = frame.index(x: x, yFromTop: y)
                }
            }
            return result
        }
        for direction in ["sw", "nw", "se", "n"] {
            #expect(try plane("stand_up_\(direction)_00") == plane("seated_idle_\(direction)_00"))
            #expect(try plane("stand_up_\(direction)_11") == plane("idle_\(direction)_00"))
            for phase in 0..<12 {
                #expect(try plane(String(format: "sit_down_%@_%02d", direction, phase))
                        == plane(String(format: "stand_up_%@_%02d", direction, 11 - phase)))
            }
        }
    }
}
