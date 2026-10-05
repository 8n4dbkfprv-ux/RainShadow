import CryptoKit
import Foundation
import Testing
@testable import RainShadowCore

struct LilaCurrentRuntimeTests {
    private var root: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }
    private func sprite() throws -> IEIndexedSprite {
        if let stage = ProcessInfo.processInfo.environment["RAINSHADOW_LILA_STAGE"] {
            return try IEIndexedSprite(contentsOf: URL(fileURLWithPath: stage).appendingPathComponent("avatar-v02.json"),
                                       tables: IEGradientTables.load())
        }
        return try IEIndexedSprite.load(character: LilaAnimationSet.character)
    }

    @Test func completeReviewedBundleDecodesEveryNativePixel() throws {
        let sprite = try sprite()
        try LilaAnimationSet.validate(sprite)
        #expect(sprite.sourceCanvasSize == .init(width: 128, height: 128))
        #expect(sprite.compatibilityDisplaySize == .init(x: 140.625, y: 140.625))
        #expect(!sprite.hasEmbeddedShadow)
        let reportURL = root.appendingPathComponent("ArtSource/Blender/LilaDesertSentinelOct02/stage_validation.json")
        let report = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: reportURL)) as? [String: Any])
        var hash = SHA256()
        for frame in sprite.frames { hash.update(data: Data(sprite.rgba(for: frame))) }
        #expect(hash.finalize().map { String(format: "%02x", $0) }.joined() == report["decoded_crop_rgba_sha256"] as? String)
    }

    @Test func allDirectionsUseTenUniqueWalkPhasesAndTheExactFemaleIdleHolds() throws {
        let sprite = try sprite()
        let schedule = [0,0,0,0,0,0,1,1,2,2,3,3,4,4,5,5,5,5,5,5,4,4,3,3,2,2,1,1,
                        0,0,0,0,0,0,6,6,7,7,8,8,9,9,10,10,10,10,10,10,9,9,8,8,7,7,6,6]
        func plane(_ name: String) throws -> Data {
            let frame = try #require(sprite.frame(atlas: LilaAnimationSet.atlas, name: name))
            var canvas = [UInt8](repeating: 0, count: 128*128)
            for y in 0..<frame.nativeSize.height {
                for x in 0..<frame.nativeSize.width {
                    let index = frame.index(x: x, yFromTop: y)
                    #expect(index == 0 || (4..<88).contains(index))
                    canvas[(y+frame.trimOriginTopLeft.height)*128+x+frame.trimOriginTopLeft.width] = index
                }
            }
            return Data(canvas)
        }
        for direction in LilaAnimationSet.directions {
            let walk = try (0..<10).map { try plane(String(format: "walk_%@_%02d.png",direction,$0)) }
            #expect(Set(walk).count == 10)
            let idle = try (0..<56).map { try plane(String(format: "idle_%@_%02d.png",direction,$0)) }
            #expect(Set(idle).count == 11)
            for phase in schedule.indices {
                #expect(idle[phase] == idle[schedule.firstIndex(of: schedule[phase])!])
            }
        }
    }

    @Test func historicalLilaCannotSatisfyTheReplacementContract() throws {
        let old = try IEIndexedSprite.load(character: "Lila")
        #expect(throws: IEIndexedSpriteError.self) { try LilaAnimationSet.validate(old) }
    }
}
