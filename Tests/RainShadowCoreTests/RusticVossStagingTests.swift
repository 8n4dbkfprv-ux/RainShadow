import CryptoKit
import Foundation
import Testing
@testable import RainShadowCore

/// Runs against an explicitly selected candidate before any runtime replacement.
struct RusticVossStagingTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["RAINSHADOW_RUSTIC_STAGE"] != nil))
    func completeCandidateLoadsAndPreservesTimingPaletteAndChairEndpoints() throws {
        let path = try #require(ProcessInfo.processInfo.environment["RAINSHADOW_RUSTIC_STAGE"])
        let directory = URL(fileURLWithPath: path)
        let sprite = try IEIndexedSprite(contentsOf: directory.appendingPathComponent("avatar-v02.json"),
                                         tables: IEGradientTables.load())
        try VossAnimationSet.validate(sprite)
        #expect(sprite.sourceCanvasSize == .init(width: 128, height: 128))
        #expect(sprite.compatibilityDisplaySize == .init(x: 140.625, y: 140.625))
        #expect(sprite.hasEmbeddedShadow)
        func plane(_ name: String) throws -> [UInt8] {
            let frame = try #require(sprite.frame(atlas: VossAnimationSet.atlas, name: name + ".png"))
            var output = [UInt8](repeating: 0, count: 128 * 128)
            for y in 0..<frame.nativeSize.height {
                for x in 0..<frame.nativeSize.width {
                    output[(y + frame.trimOriginTopLeft.height) * 128 + x + frame.trimOriginTopLeft.width] = frame.index(x: x, yFromTop: y)
                }
            }
            return output
        }
        // CHMB1G12 cycle 18: eleven poses, with the original turn/hold/reverse schedule.
        let poses = [0,0,1,1,2,2,3,3,4,4,5,5,5,5,5,5,5,5,4,4,3,3,2,2,1,1,0,0,0,0,0,0,0,0,6,6,7,7,8,8,9,9,10,10,10,10,10,10,10,10,9,9,8,8,7,7,6,6,0,0,0,0,0,0,0]
        for direction in VossAnimationSet.directions {
            var first: [Int: [UInt8]] = [:]
            for phase in 0..<65 {
                let p = try plane(String(format: "idle_%@_%02d", direction, phase))
                if let previous = first[poses[phase]] { #expect(p == previous) }
                else { first[poses[phase]] = p }
            }
            #expect(Set(first.values).count >= 6)
            let walks = try (0..<10).map { try plane(String(format: "walk_%@_%02d", direction, $0)) }
            #expect(Set(walks).count == 10)
        }
        for direction in ["sw", "nw", "se", "n"] {
            #expect(try plane("stand_up_\(direction)_00") == plane("seated_idle_\(direction)_00"))
            #expect(try plane("stand_up_\(direction)_11") == plane("idle_\(direction)_00"))
            for phase in 0..<12 {
                #expect(try plane(String(format: "sit_down_%@_%02d", direction, phase))
                        == plane(String(format: "stand_up_%@_%02d", direction, 11 - phase)))
            }
        }
        let auditURL = directory.deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("stage_validation.json")
        let audit = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: auditURL)) as? [String: Any])
        var hash = SHA256()
        for frame in sprite.frames { hash.update(data: Data(sprite.rgba(for: frame))) }
        #expect(hash.finalize().map { String(format: "%02x", $0) }.joined() == audit["rgba_sha256"] as? String)
    }
}
