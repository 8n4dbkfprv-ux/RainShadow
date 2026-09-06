import Foundation
import Testing
@testable import RainShadowCore

struct MeshyV04SpriteTests {
    @Test func approvedCandidatePreservesNativePixelsAndTranslucentShadows() throws {
        let url = VossAtlasTestAssets.indexedManifestURL()
        let sprite = try IEIndexedSprite(contentsOf: url, tables: IEGradientTables.load())
        #expect(sprite.frames.count == 248)
        #expect(sprite.hasEmbeddedShadow)
        #expect(sprite.compatibilityDisplaySize == .init(x: 163.125, y: 163.125))
        var alternate = sprite.colors
        alternate[5] = 42
        var shadows = 0
        for frame in sprite.frames {
            let rgba = sprite.rgba(for: frame)
            let recolored = sprite.rgba(for: frame, colors: alternate)
            #expect(rgba.count == frame.indices.count * 4)
            for (offset, index) in frame.indices.enumerated() {
                let alpha: UInt8 = index == 0 ? 0 : index == 1 ? 128 : 255
                #expect(rgba[offset * 4 + 3] == alpha)
                #expect(recolored[offset * 4 + 3] == alpha)
                if index == 1 { shadows += 1 }
            }
            if frame.id.atlas == "VossIdle.atlas" || frame.id.atlas == "VossWalk.atlas" {
                let rows = frame.indices.enumerated().compactMap { offset, index in
                    index >= 4 && index < 88 ? offset / frame.nativeSize.width : nil
                }
                #expect((try #require(rows.max())) - (try #require(rows.min())) + 1 == 58)
            }
        }
        #expect(shadows > 0)
    }
    @Test func transitionEndpointsAndReverseFramesAreExact() throws {
        let sprite = try VossAtlasTestAssets.indexedSprite()
        func same(_ atlasA: String, _ nameA: String, _ atlasB: String, _ nameB: String) throws {
            let a = try #require(sprite.frame(atlas: atlasA, name: nameA))
            let b = try #require(sprite.frame(atlas: atlasB, name: nameB))
            #expect(a.indices == b.indices)
            #expect(a.nativeSize == b.nativeSize)
            #expect(a.trimOriginTopLeft == b.trimOriginTopLeft)
        }
        for (direction, standing) in [("ne", "nw"), ("se", "se"), ("n", "n")] {
            try same("VossSeatTransitions.atlas", "voss_stand_up_\(direction)_00.png",
                     "VossSeatedIdle.atlas", "voss_seated_idle_\(direction)_00.png")
            try same("VossSeatTransitions.atlas", "voss_stand_up_\(direction)_11.png",
                     "VossIdle.atlas", "voss_standing_idle_\(standing)_00.png")
            for frame in 0..<12 {
                try same("VossSeatTransitions.atlas", String(format: "voss_stand_up_%@_%02d.png", direction, frame),
                         "VossSeatTransitions.atlas", String(format: "voss_sit_down_%@_%02d.png", direction, 11-frame))
            }
        }
    }
}
